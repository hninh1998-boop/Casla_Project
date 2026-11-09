@EndUserText.label: 'Param - Upload Attachment SO'
define abstract entity ZABS_UPL_ATT_SO
{
  fileName    : abap.char(255);
  mimeType    : abap.char(128);
  fileContent : abap.rawstring(0);
}
