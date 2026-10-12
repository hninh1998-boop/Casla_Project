@EndUserText.label: 'Abstract Entity - Sales Đá Export Result'
define abstract entity zabs_sales_da_result
{
  MimeType      : abap.string(0);
  FileName      : abap.string(0);
  FileContent   : abap.string(0); // base64
  FileExtension : abap.string(0);
}
