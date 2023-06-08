# These were the versions as of 2023-06-03
# archlinux:base-20230528.0.154326
# mingw-w64-tools 10.0.0-1 
# openwatcom-v2 2.0-8
# kjliew/qemu-3dfx 0f2faac

# podman build --tag 3dfx .
# podman run --rm -it 3dfx
# for d in 3dfx mesa; do podman cp 3dfx:/home/user/qemu-3dfx/wrappers/${d}/build "$d"; done
# podman cp 3dfx:/home/user/qemu-3dfx/qemu-8.0.0/build qemu

FROM archlinux:latest
RUN pacman --refresh --sync --noconfirm sudo git
RUN useradd --groups wheel --create-home user
RUN echo 'user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers
USER user
WORKDIR /home/user

RUN sudo pacman --sync --noconfirm fakeroot binutils
RUN git clone https://aur.archlinux.org/paru-bin.git
RUN cd paru-bin && makepkg --install --noconfirm

RUN paru --sync --noconfirm gcc make
RUN paru --sync --cleanafter mingw-w64-tools # provides gendef

RUN paru --sync --cleanafter openwatcom-v2

# There's an AUR for this but it ends up compiling GCC
RUN \
	curl -L 'https://github.com/andrewwutw/build-djgpp/releases/download/v3.3/djgpp-linux64-gcc1210.tar.bz2' \
	| sudo tar -C /opt -xj
ENV PATH "$PATH:/opt/djgpp/bin:/opt/djgpp/i586-pc-msdosdjgpp/bin:/opt/watcom/binl:/usr/bin/core_perl"

# qemu build deps
RUN curl -L 'https://download.qemu.org/qemu-8.0.0.tar.xz' | tar -xJ
RUN paru --sync --noconfirm pkg-config ninja python patch diffutils pixman sdl2

# wrapper build deps
RUN paru --sync --noconfirm vim which mingw-w64-gcc flex # vim provides xxd

COPY --chown=user . qemu-3dfx
WORKDIR /home/user/qemu-3dfx

RUN \
	mv ../qemu-8.0.0 . && \
	cd qemu-8.0.0 && \
	cp -r ../qemu-0/hw/3dfx ./hw/ && \
	cp -r ../qemu-1/hw/mesa ./hw/ && \
	patch -p0 -i ../00-qemu800-mesa-glide.patch && \
	bash ../scripts/sign_commit && \
	./configure --target-list=i386-softmmu && \
	make -j 8

RUN \
	mkdir wrappers/{3dfx,mesa}/build && \
	pushd wrappers/3dfx/build && \
	bash ../../../scripts/conf_wrapper && \
	make && make clean && popd && \
	pushd wrappers/mesa/build && \
	bash ../../../scripts/conf_wrapper && \
	make && make clean
