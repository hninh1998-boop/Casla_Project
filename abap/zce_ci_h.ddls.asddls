@EndUserText.label: 'Custom Entity - Commercial Invoice Header'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_CI_Q'
@Metadata.allowExtensions: true
define root custom entity zce_ci_h
{
      // Màn hình ngoài: mỗi Pro-forma invoice 1 dòng (FS v8 - Layout Screen)
  key ProFormaInvoice   : vbeln;

      ToCI              : abap.string;
      Invoice           : abap.string;        // Điền tay - ztb_ci_text
      DateCI            : fkdat;
      PO                : bstkd;
      MBL               : abap.string;        // Điền tay
      HBL               : abap.string;        // Điền tay
      VesselName        : abap.string;        // Long text Z038, có điền tay thì lấy giá trị điền
      ETD               : abap.string;        // Long text DO Z010, có điền tay thì lấy giá trị điền
      ETA               : abap.string;        // Điền tay
      ContainerNo       : abap.string;
      PortOfLoading     : abap.char(70);
      PortOfDestination : abap.char(70);
      PriceTerm         : abap.char(35);
      CountryOfOrigin   : abap.char(20);

      // Filter
      SalesOrganization : vkorg;
      Customer          : kunrg;

      _Item             : composition [0..*] of zce_ci_i;
}
