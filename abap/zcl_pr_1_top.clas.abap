CLASS zcl_pr_1_top DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_data_grp,
             type                    TYPE c LENGTH 1,
             purchaserequisition     TYPE c LENGTH 10,
             purchaserequisitiontype TYPE bbsrt,
             purreqndescription      TYPE c LENGTH 40,
             purreqnheadernote       TYPE string,
           END OF ty_data_grp.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PR_1_TOP IMPLEMENTATION.
ENDCLASS.
