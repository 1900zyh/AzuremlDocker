FROM nvidia/cuda@sha256:853e4cbf7c48bbfa04977bc5998d4b60f3310692446184230649d7fdc053fd44

USER root:root

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV DEBIAN_FRONTEND noninteractive
ENV LD_LIBRARY_PATH "/usr/local/cuda/extras/CUPTI/lib64:${LD_LIBRARY_PATH}"

# Install Common Dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # SSH and RDMA
    libmlx4-1 \
    libmlx5-1 \
    librdmacm1 \
    libibverbs1 \
    libmthca1 \
    libdapl2 \
    dapl2-utils \
    openssh-client \
    openssh-server && \
    apt-get install -y --no-install-recommends \
    --allow-change-held-packages \
    vim \
    tmux \
    unzip \
    libnccl2 \
    libnccl-dev \
    ca-certificates \
    libjpeg-dev \
    wget \
    iproute2 && \
    # Others
    apt-get install -y \
    build-essential \
    bzip2 \
    git=1:2.7.4-0ubuntu1.6 \
    cpio && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Install lib for video
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:jonathonf/ffmpeg-3
RUN apt update && apt-get install -y libavformat-dev libavcodec-dev libswscale-dev libavutil-dev libswresample-dev
RUN apt-get install -y ffmpeg
RUN export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

# Set timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# Conda Environment
ENV MINICONDA_VERSION latest
ENV PATH /opt/miniconda/bin:$PATH
RUN wget -qO /tmp/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    bash /tmp/miniconda.sh -bf -p /opt/miniconda && \
    conda clean -ay && \
    rm -rf /opt/miniconda/pkgs && \
    rm /tmp/miniconda.sh && \
    find / -type d -name __pycache__ | xargs rm -rf

# Intel MPI installation
ENV INTEL_MPI_VERSION 2018.3.222
ENV PATH $PATH:/opt/intel/compilers_and_libraries/linux/mpi/bin64
RUN cd /tmp && \
    wget -q "http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/13063/l_mpi_${INTEL_MPI_VERSION}.tgz" && \
    tar zxvf l_mpi_${INTEL_MPI_VERSION}.tgz && \
    sed -i -e 's/^ACCEPT_EULA=decline/ACCEPT_EULA=accept/g' /tmp/l_mpi_${INTEL_MPI_VERSION}/silent.cfg && \
    cd /tmp/l_mpi_${INTEL_MPI_VERSION} && \
    ./install.sh -s silent.cfg --arch=intel64 && \
    cd / && \
    rm -rf /tmp/l_mpi_${INTEL_MPI_VERSION}* && \
    rm -rf /opt/intel/compilers_and_libraries_${INTEL_MPI_VERSION}/linux/mpi/intel64/lib/debug* && \
    echo "source /opt/intel/compilers_and_libraries_${INTEL_MPI_VERSION}/linux/mpi/intel64/bin/mpivars.sh" >> ~/.bashrc

RUN conda install -y python=3.6 numpy pyyaml scipy ipython mkl scikit-learn matplotlib pandas setuptools Cython h5py graphviz libgcc mkl-include cmake cffi typing cython && \
     conda install -y -c mingfeima mkldnn && \
     conda install -c anaconda gxx_linux-64
RUN conda clean -ya
RUN pip install boto3 addict tqdm regex pyyaml opencv-python azureml-defaults opencv-contrib-python nltk spacy
# Set CUDA_ROOT
RUN export CUDA_HOME="/usr/local/cuda"

# Install pytorch
RUN conda install -y pytorch torchvision  -c pytorch
#Install Faiss
RUN conda install faiss-gpu cudatoolkit=10.0 -c pytorch # For CUDA10

# Install horovod
RUN HOROVOD_GPU_ALLREDUCE=NCCL pip install --no-cache-dir horovod==0.16.1

#Install apex
RUN pip uninstall -y apex || :
RUN cd /tmp && \
    SHA=ToUcHMe git clone https://github.com/NVIDIA/apex.git
RUN cd /tmp/apex/ && \
    python setup.py install --cuda_ext --cpp_ext && \
    rm -rf /tmp/apex*
