FROM ctfd/ctfd:latest

COPY CTFd/themes/core/templates/components/labs_modal.html /opt/CTFd/CTFd/themes/core/templates/components/labs_modal.html
COPY CTFd/themes/core/static/js/labs.js /opt/CTFd/CTFd/themes/core/static/js/labs.js
COPY CTFd/themes/core/static/css/labs.css /opt/CTFd/CTFd/themes/core/static/css/labs.css
COPY docker/ctfd/patch_navbar.py /tmp/patch_navbar.py

RUN python /tmp/patch_navbar.py
