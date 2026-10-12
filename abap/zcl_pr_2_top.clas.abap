CLASS zcl_pr_2_top DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    TYPES: tt_entities  TYPE TABLE FOR CREATE zi_m_pr_2\\managefilepr2,
           tt_mapped    TYPE RESPONSE FOR MAPPED EARLY zi_m_pr_2,
           tt_reported  TYPE RESPONSE FOR REPORTED EARLY zi_m_pr_2,
           tt_failed    TYPE RESPONSE FOR FAILED EARLY zi_m_pr_2,
           tt_keys      TYPE TABLE FOR ACTION IMPORT zi_m_pr_2\\managefilepr2~uploadexcelpr2,
           tt_mn_file   TYPE TABLE FOR CREATE zi_m_pr_2\\managefilepr2,
           tt_data_file TYPE STANDARD TABLE OF zi_d_pr_2,
           tt_file_c    TYPE TABLE FOR CREATE zi_m_pr_2\\ManageFilePR2\_datafile,
           tt_record    TYPE TABLE FOR READ RESULT zi_m_pr_2\\managefilepr2,
           tt_data      TYPE STANDARD TABLE OF ztb_d_pr_2 WITH EMPTY KEY..

    TYPES: BEGIN OF ty_file_upload,
             Type                     TYPE string,
             PurchaseRequisition      TYPE string,
             PurchaseRequisitionItem  TYPE string,
             Material                 TYPE string,
             RequestedQuantity        TYPE string,
             BaseUnit                 TYPE string,
             Plant                    TYPE string,
             StorageLocation          TYPE string,
             PurchaseRequisitionPrice TYPE string,
             PurReqnPriceQuantity     TYPE string,
             PurReqnItemCurrency      TYPE string,
             PurchasingGroup          TYPE string,
             DeliveryDate             TYPE string,
             RequirementTracking      TYPE string,
             RequisitionerName        TYPE string,
           END OF ty_file_upload,
           tt_file_upload TYPE STANDARD TABLE OF ty_file_upload.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PR_2_TOP IMPLEMENTATION.
ENDCLASS.
