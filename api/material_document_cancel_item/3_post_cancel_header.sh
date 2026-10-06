# 3. Post cancel matdoc header - hủy cả chứng từ; x-csrf-token lấy từ response header của bước 1
curl --location --request POST 'https://my426501-api.s4hana.cloud.sap/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV/Cancel?MaterialDocumentYear=%272026%27&MaterialDocument=%274900005992%27&PostingDate=datetime%272026-10-06T00:00:00%27' \
--header 'Accept: application/json' \
--header 'x-csrf-token: <token từ bước 1>' \
--user '<api_user>:<api_password>' \
--cookie cookies.txt
