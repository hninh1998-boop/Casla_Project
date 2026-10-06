# 2. Post cancel matdoc item - x-csrf-token lấy từ response header của bước 1
curl --location --request POST 'https://my426501-api.s4hana.cloud.sap/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV/CancelItem?MaterialDocumentYear=%272025%27&MaterialDocument=%274900000001%27&MaterialDocumentItem=%270001%27&PostingDate=datetime%272025-08-14T00:00:00%27' \
--header 'Accept: application/json' \
--header 'x-csrf-token: <token từ bước 1>' \
--user '<api_user>:<api_password>' \
--cookie cookies.txt
