#
# Build UXTC person tracking docker container
#
#  docker build -t uxtc/openpose:1.0 -t uxtc/openpose:latest .
#

FROM nvidia/cuda:8.0-cudnn5-devel-ubuntu16.04

RUN apt-get update && \ 
    apt-get install -y \
    build-essential cmake git \ 
    pkg-config \
    libjpeg8-dev libtiff5-dev libjasper-dev libpng12-dev libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libx264-dev libx265-dev \
    libatlas-base-dev \
    gfortran \
    python3.5-dev python3-pip \
    libboost-all-dev \
    libgflags-dev libgoogle-glog-dev libprotobuf-lite9v5 libprotobuf-dev protobuf-compiler \
    wget unzip \
    libhdf5-serial-dev libleveldb-dev liblmdb-dev \
    libsnappy-dev \
    yasm && \
    rm -rf /var/lib/apt/lists/*   # clean up

RUN pip3 install && pip3 install numpy

# opencv (3.2 specifically)
# ensure dnn is NOT enabled, this will cause problems!
RUN cd && \
    wget -O opencv.zip https://github.com/opencv/opencv/archive/3.2.0.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/3.2.0.zip && \
    unzip opencv.zip && \
    unzip opencv_contrib.zip && \
    rm -f opencv.zip && \
    rm -f opencv_contrib.zip
RUN cd ~/opencv-3.2.0/ && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
      -D BUILD_opencv_dnn=OFF \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D INSTALL_PYTHON_EXAMPLES=OFF \
      -D INSTALL_C_EXAMPLES=OFF \
      -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib-3.2.0/modules \
      -D PYTHON3_EXECUTABLE=`which python3` \
      -D BUILD_opencv_python2=OFF \
      -D BUILD_opencv_python3=ON \
      -D BUILD_EXAMPLES=OFF .. && \
    make -j"$(nproc)" && \
    make install -j"$(nproc)" && \
    ldconfig && \
    cd ~ && \
    rm -rf opencv-3.2.0 && \
    rm -rf opencv_contrib-3.2.0
    
RUN cd /opt && \
    wget -O openpose.zip https://github.com/CMU-Perceptual-Computing-Lab/openpose/archive/v1.2.1.zip && \
    unzip openpose.zip && \
    rm -f openpose.zip && \
    mv openpose-1.2.1 openpose-master

ENV CAFFE_ROOT=/opt/openpose-master/3rdparty/caffe
# Added due to error: /bin/sh: 1: pip: not found 
RUN set -xe \
    && apt-get update \
    && apt-get install -y python-pip

# Caffe
RUN cd /opt/openpose-master && \
    rm -rf 3rdparty/caffe && \
    git clone --depth 1 https://github.com/CMU-Perceptual-Computing-Lab/caffe.git 3rdparty/caffe && \
    cd 3rdparty/caffe/ && \
    cp Makefile.config.Ubuntu16_cuda8.example Makefile.config && \
    sed -i '/\# OPENCV_VERSION := 3/c\OPENCV_VERSION := 3' Makefile.config && \
    sed -i '/\# PYTHON_LIBRARIES := boost_python3 python3.5m/c\PYTHON_LIBRARIES := boost_python3 python3.5m' Makefile.config && \
    sed -i '/\# PYTHON_INCLUDE := \/usr\/include\/python3.5m \\/c\PYTHON_INCLUDE := \/usr\/include\/python3.5m \\' Makefile.config && \
    sed -i '/\#                 \/usr\/lib\/python3.5\/dist-packages\/numpy\/core\/include/c\                  \/usr\/local\/lib\/python3.5\/dist-packages\/numpy\/core\/include' Makefile.config && \
    cd python && \
    for req in $(cat requirements.txt) pydot; do pip install $req; done && \
    cd .. && \
    ln -s /usr/lib/x86_64-linux-gnu/libboost_python-py35.so /usr/lib/x86_64-linux-gnu/libboost_python3.so && \
    make all -j"$(nproc)"

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig
RUN cd /opt/openpose-master/3rdparty/caffe && make distribute -j"$(nproc)"

# Compile openpose
ENV OPENPOSE_ROOT /opt/openpose-master
RUN cd /opt/openpose-master && \
    cp ubuntu/Makefile.config.Ubuntu16_cuda8.example Makefile.config && \
    sed -i '/\# OPENCV_VERSION := 3/c\OPENCV_VERSION := 3' Makefile.config && \
    make all -j"$(nproc)"

CMD ["ls", "-l", "/opt"]
