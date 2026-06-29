CLASS zbp_i_user_gb DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_user_gb.
  PUBLIC SECTION.

    TYPES: BEGIN OF gty_gr_xl,
             po_number       TYPE string, """ Template
             po_item         TYPE string, """ Template
             gr_quantity     TYPE string, """ Template
             unit_of_measure TYPE string, """ Template
             site_id         TYPE string, """ Template
             header_text     TYPE string, """ Template
             line_number     TYPE string,
             line_id         TYPE string,
           END OF gty_gr_xl.

ENDCLASS.

CLASS zbp_i_user_gb IMPLEMENTATION.
ENDCLASS.
