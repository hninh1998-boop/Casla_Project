@EndUserText.label: 'Abs.Ent. - Mapping Inv-Matdoc Export Result'
define abstract entity zabs_mapim_export_result
{
  MimeType      : abap.string(0);
  FileName      : abap.string(0);
  FileContent   : abap.string(0); // base64
  FileExtension : abap.string(0);
}
