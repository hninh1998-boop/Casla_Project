# 1. Get cancel matdoc item - lấy x-csrf-token + cookie cho bước POST
curl --location 'https://my426501-api.s4hana.cloud.sap/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV/' \
--header 'Accept: application/json' \
--header 'x-csrf-token: fetch' \
--user '<api_user>:<api_password>' \
--cookie-jar cookies.txt \
--include
