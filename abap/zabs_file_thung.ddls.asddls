@EndUserText.label: 'Abs.Ent. - File upload thùng mẫu'
define abstract entity zabs_file_thung
{
  mimeType      : abap.string(0);
  fileName      : abap.string(0);
  fileContent   : abap.rawstring(0);
  fileExtension : abap.string(0);

}
