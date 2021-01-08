#!/bin/sh

/usr/bin/soffice \
    --headless \
    --invisible \
    --nodefault \
    --nofirststartwizard \
    --nolockcheck \
    --nologo \
    --norestore \
    --convert-to pdf:writer_pdf_Export \
    --outdir /tmp \
    /home/app/test-template.docx \
        &> /home/app/output_and_error_file

ls /tmp >> /home/app/output_and_error_file

exec python -m awslambdaric $1
