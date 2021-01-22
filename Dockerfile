FROM ubuntu:18.04
COPY ./HTK-3.4.1.tar /home
COPY ./HDecode-3.4.1.tar /home
RUN cd /home \
	&& tar xvf HTK-3.4.1.tar \
	&& tar xvf HDecode-3.4.1.tar
RUN apt-get update \
	&& apt-get install -y git \
	&& apt install -y build-essential gcc-multilib 
RUN cd /home/htk \
	&& sed -i 's/^ \+/\t/' HLMTools/Makefile.in \
	&& ./configure --disable-hslab \
	&& make all \
	&& make install \
	&& make hdecode \
	&& make install-hdecode
RUN cd / \
 	&& git clone https://github.com/nassosoassos/sail_align
RUN cd /sail_align \
	&& export PERL_MM_USE_DEFAULT=1 \
	&& cpan Module::Build \
	&& cpan LWP::Simple \
	&& cpan Archive::Extract \
	&& perl Build.PL \
	&& ./Build installdeps \
	&& ./Build \
	&& ./Build install
