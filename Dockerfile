FROM archlinux:base-devel-20220508.0.55614 as base
RUN pacman -Sy --noconfirm help2man vi

FROM base as build-ct-ng
WORKDIR /tmp
ARG CT_NG_VERSION
RUN curl -O http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-${CT_NG_VERSION}.tar.bz2
RUN tar xf crosstool-ng-${CT_NG_VERSION}.tar.bz2
WORKDIR /tmp/crosstool-ng-${CT_NG_VERSION}
RUN pacman -S --noconfirm unzip
RUN ./configure --prefix=/usr/local
RUN make
RUN make install

FROM base as ct-ng
COPY --from=build-ct-ng /usr/local/ /usr/local/
ARG GID=1000
RUN groupadd -g ${GID} cross
ARG UID=1000
RUN useradd -m -u ${UID} -g ${GID} cross
RUN gpasswd -a cross wheel
RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
USER cross
WORKDIR /home/cross

FROM ct-ng as x-tools
ARG TARGET_SPEC
COPY ${TARGET_SPEC}/crosstool-ng.config .config
RUN ct-ng build
ARG CT_NG_TARGET
ENV PATH=/home/cross/x-tools/${CT_NG_TARGET}/bin:${PATH}

FROM x-tools as x-busybox
ARG BUSYBOX_VERSION
RUN curl -sL https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 | tar xjf -
WORKDIR /home/cross/busybox-${BUSYBOX_VERSION}
RUN make defconfig
ARG CT_NG_TARGET
RUN make -j $(($(nproc)+1)) CROSS_COMPILE=${CT_NG_TARGET}-
RUN make -j $(($(nproc)+1)) CROSS_COMPILE=${CT_NG_TARGET}- CONFIG_PREFIX=/tmp/busybox install

FROM x-tools as x-kernel
ARG LINUX_VERSION
RUN curl -sL https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VERSION}.tar.xz | tar xJf -
WORKDIR /home/cross/linux-${LINUX_VERSION}
ARG TARGET_SPEC
COPY --chown=cross:cross ${TARGET_SPEC}/linux.config .config
COPY --chown=cross:cross ${TARGET_SPEC}/linux.patch /tmp
RUN patch -p1 -i /tmp/linux.patch
RUN sudo pacman -S --noconfirm bc
RUN > /home/cross/initramfs.cpiol
ARG LINUX_ARCH
ARG CT_NG_TARGET
RUN make -j $(($(nproc)+1)) ARCH=${LINUX_ARCH} CROSS_COMPILE=${CT_NG_TARGET}- V=1 vmlinux

FROM x-kernel as x-system
COPY --chown=cross:cross ./base.cpiol /home/cross/initramfs.cpiol
COPY --from=x-busybox /tmp/busybox/ /tmp/busybox/
COPY ./fs2cpiol /usr/local/bin/
RUN fs2cpiol /tmp/busybox >> /home/cross/initramfs.cpiol
ARG LINUX_ARCH
ARG CT_NG_TARGET
RUN make -j $(($(nproc)+1)) ARCH=${LINUX_ARCH} CROSS_COMPILE=${CT_NG_TARGET}- V=1 vmlinux
RUN objcopy -O srec vmlinux vmlinux.srec

FROM alpine:3.15.4 as pxe
RUN apk update
RUN apk add dnsmasq
ARG LINUX_VERSION
ARG TARGET_SPEC
COPY --from=x-system --chown=root:root /home/cross/linux-${LINUX_VERSION}/vmlinux.srec /tmp/tftp/${TARGET_SPEC}
ENTRYPOINT ["dnsmasq", \
    "--no-hosts", \
    "--keep-in-foreground", \
    "--log-facility=/dev/stdout", \
    "--port=0", \
    "--enable-tftp", \
    "--tftp-root=/tmp/tftp"]
