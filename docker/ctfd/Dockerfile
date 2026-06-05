FROM ctfd/ctfd:latest

COPY CTFd-custom/themes/core/templates/components/navbar.html /opt/CTFd/CTFd/themes/core/templates/components/navbar.html
COPY CTFd-custom/themes/core/templates/components/labs_modal.html /opt/CTFd/CTFd/themes/core/templates/components/labs_modal.html
COPY CTFd-custom/themes/core/static/js/labs.js /opt/CTFd/CTFd/themes/core/static/js/labs.js
COPY CTFd-custom/themes/core/static/css/labs.css /opt/CTFd/CTFd/themes/core/static/css/labs.css

RUN cp /opt/CTFd/CTFd/themes/core/static/js/labs.js /opt/CTFd/CTFd/themes/core/static/js/labs.min.js \
    && cp /opt/CTFd/CTFd/themes/core/static/css/labs.css /opt/CTFd/CTFd/themes/core/static/css/labs.min.css
