CLASS lhc_XLData DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR XLData RESULT result.

    METHODS processData FOR MODIFY
      IMPORTING keys FOR ACTION XLData~processData RESULT result.

ENDCLASS.

CLASS lhc_XLData IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD processData.
  ENDMETHOD.

ENDCLASS.
