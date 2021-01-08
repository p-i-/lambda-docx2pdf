import os
import sys
import boto3
import shutil
import subprocess

from io import BytesIO

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

BUCKET_NAME = 'leafsheets-django'
BUCKET_SRC_DOC_FOLDER = 'static/fixtures/docs'
BUCKET_DST_DOC_FOLDER = 'private/documents/pdfs/user'
LIBRE_BINARY = '/usr/bin/soffice'
TMP_FOLDER = '/tmp'

# # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# import json
# import platform
# def handler(event, context): 
#     return f'Hello from AWS Lambda using Python {platform.python_version()}, Event data: {json.dumps(event)}'

import stat
def handler(event, context):
    workdir = '/home/app'
    files = ' '.join( os.listdir(workdir) )

    # on remote, fails for /home/app (FileNotFoundError), succeeds for /tmp
    perms = str( oct(stat.S_IMODE(os.stat(f'{workdir}/output_and_error_file').st_mode)) )

    error = None
    try:
        # on remote, fails for /home/app (FileNotFoundError), succeeds for /tmp
        with open(f'{workdir}/output_and_error_file', 'r') as file:
            data = file.read()
    except FileNotFoundError as e:
        error = e
    except:
        error = "Unknown error"

    return {
        f'files in {workdir}/' : files,
        f'{workdir}/output_and_error_file' : data,
        'perms' : perms,
        'error' : error
    }

    # - - - - - - -

    src_filename = event['filename']

    filename_body, _ = os.path.splitext(src_filename)

    src_filepath = f'{TMP_FOLDER}/{src_filename}'
    src_s3 = f'{BUCKET_SRC_DOC_FOLDER}/{src_filename}'

    local_pdf_filepath = f'{TMP_FOLDER}/{filename_body}.pdf'

    dst_s3_key = f'{BUCKET_DST_DOC_FOLDER}/{filename_body}'
    dst_filepath = f'{BUCKET_DST_DOC_FOLDER}/{filename_body}.pdf'

    # s3_bucket = boto3.resource('s3').Bucket(BUCKET_NAME)

    # Download object to be converted from s3 to TMP_FOLDER
    # with open(src_filepath, 'wb') as data:
    #     s3_bucket.download_fileobj(src_s3, data)
    # src_filepath is /tmp/test-template.docx

    # TODO: Revert to S3, once tests ok
    shutil.copyfile('/home/app/test-template.docx', '/tmp/test-template.docx')

    print( subprocess.check_output(['ls', '-l', '/tmp'] ) )
    print( LIBRE_BINARY )
    print( subprocess.check_output(['ls', '-l', LIBRE_BINARY] ) )

    MAX_TRIES = 3
    success = False

    print(f'Processing file: {src_filepath} with LibreOffice')
    for kTry in range(MAX_TRIES):
        # Attempt conversion
        print(f'Conversion Attempt #{kTry}')
        try:
            # https://stackoverflow.com/questions/4256107/running-bash-commands-in-python
            result = subprocess.run(
                [
                    LIBRE_BINARY,
                        '--headless',
                        '--invisible',
                        '--nodefault',
                        '--nofirststartwizard',
                        '--nolockcheck',
                        '--nologo',
                        '--norestore',
                        '--convert-to', 'pdf:writer_pdf_Export',
                        '--outdir', TMP_FOLDER,
                        src_filepath
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
                check=True,
                text=True
            )

        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"\tGot exit code {e.returncode}. Msg: {e.output}") from e
            continue

        except:
            print( f'Unknown error with conversion: {sys.exc_info()[0]}' )
            continue

        print( f"Conversion result: {result.stdout}" )

        try:
            with open(local_pdf_filepath, 'rb') as f:
                # Save the converted object to S3
                print('Saving converted file to S3')
                # s3_bucket.put_object(Key=dst_s3_key, Body=f, ACL='public-read')
        except:
            print( f'Unknown error with saving to S3: {sys.exc_info()[0]}' )
            continue

        print('Completed!')
        success = True
        break

    return { 'Response' : 'Success' if success else 'Fail' }

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# For local dev, create this file (empty is ok)
# LOCAL_DEV = os.path.isfile('.localdev')

# if LOCAL_DEV:
#     LIBRE_TARFILE = 'lo.tar.br'
#     TMP_FOLDER = './tmp'  # to avoid problem with write-perms outside of project root
#     LIBRE_BINARY = '/Applications/LibreOffice.app/Contents/MacOS/soffice'  # Need to install LibreOffice on macOS

#     # (re)create empty TMP_FOLDER
#     if os.path.exists(TMP_FOLDER):
#         shutil.rmtree(TMP_FOLDER)
#     os.makdirs(TMP_FOLDER+'/')  # https://stackoverflow.com/questions/6692678/python-mkdir-to-make-folder-with-subfolder
# else:
    # LIBRE_TARFILE = '/opt/lo.tar.br'
    # LIBRE_BINARY = '/tmp/instdir/program/soffice.bin'

# LIBRE_TARFILE = '/opt/lo.tar.br'
# LIBRE_BINARY = '/tmp/instdir/program/soffice.bin'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# Unpack LibreOffice binary into temp folder
# def cold_start():
#     with open(LIBRE_TARFILE, 'rb') as f:
#         read_file = f.read()
#         data = brotli.decompress(read_file)
#         with open(f'{TMP_FOLDER}/lo.tar', 'wb+') as write_file:
#             tar = tarfile.open(fileobj = BytesIO(data))
#             for g in tar:
#                 print(f'Extracting file: {g.name}')
#                 tar.extract(g.name, path=f'{TMP_FOLDER}/')

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# cold_start()
