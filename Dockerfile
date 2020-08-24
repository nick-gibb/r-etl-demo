FROM rocker/geospatial
RUN install2.r --error \
    --deps TRUE \
    janitor \
	AzureStor \
	jsonlite \
	cansim
RUN installGithub.r cloudyr/limer \
&& rm -rf /tmp/downloaded_packages/


RUN useradd --create-home appuser
WORKDIR /home/appuser
USER appuser

COPY myscript.R .

CMD ["Rscript", "myscript.R"]