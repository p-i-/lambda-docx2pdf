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

def handler(event, context):
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

        # try:
        #     with open(local_pdf_filepath, 'rb') as f:
        #         # Save the converted object to S3
        #         print('Saving converted file to S3')
        #         s3_bucket.put_object(Key=dst_s3_key, Body=f, ACL='public-read')
        # except:
        #     print( f'Unknown error with saving to S3: {sys.exc_info()[0]}' )
        #     continue

        print('Completed!')
        success = True
        break

    return { 'Response' : 'Success' if success else 'Fail' }

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
