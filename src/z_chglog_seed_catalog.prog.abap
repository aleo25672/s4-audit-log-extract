REPORT z_chglog_seed_catalog.

TYPES:
  BEGIN OF ty_status,
    entity      TYPE c LENGTH 10,
    process     TYPE ztproc_chdo-process,
    objectclas  TYPE ztproc_chdo-objectclas,
    descr       TYPE ztproc_chdo-descr,
    in_tcdob    TYPE abap_bool,
    seen_cdhdr  TYPE abap_bool,
    action      TYPE c LENGTH 30,
  END OF ty_status.

DATA gt_process TYPE STANDARD TABLE OF ztprocess WITH EMPTY KEY.
DATA gt_seed TYPE STANDARD TABLE OF ztproc_chdo WITH EMPTY KEY.
DATA gt_status TYPE STANDARD TABLE OF ty_status WITH EMPTY KEY.

START-OF-SELECTION.
  PERFORM build_seed.
  PERFORM validate_and_seed.
  PERFORM display_status.


FORM build_seed.
  gt_process = VALUE #(
    ( mandt = sy-mandt process = 'P2P' active = abap_true
      seq = '010' descr = 'Sourcing to Payment' )
    ( mandt = sy-mandt process = 'O2C' active = abap_true
      seq = '020' descr = 'Order to Cash' )
    ( mandt = sy-mandt process = 'R2R' active = abap_true
      seq = '030' descr = 'Record to Report' ) ).

  gt_seed = VALUE #(
    ( mandt = sy-mandt process = 'P2P' objectclas = 'BANF'
      active = abap_true seq = '010' descr = 'Purchase Requisition' )
    ( mandt = sy-mandt process = 'P2P' objectclas = 'EINKBELEG'
      active = abap_true seq = '020' descr = 'Purchasing Document' )
    ( mandt = sy-mandt process = 'P2P' objectclas = 'INCOMINGINVOICE'
      active = abap_true seq = '030' descr = 'Incoming Invoice' )
    ( mandt = sy-mandt process = 'O2C' objectclas = 'VERKBELEG'
      active = abap_true seq = '010' descr = 'Sales Document' )
    ( mandt = sy-mandt process = 'O2C' objectclas = 'LIEFERUNG'
      active = abap_true seq = '020' descr = 'Delivery' )
    ( mandt = sy-mandt process = 'O2C' objectclas = 'FAKTBELEG'
      active = abap_true seq = '030' descr = 'Billing Document' )
    ( mandt = sy-mandt process = 'R2R' objectclas = 'BELEG'
      active = abap_true seq = '010' descr = 'FI Accounting Document' ) ).
ENDFORM.


FORM validate_and_seed.
  DATA lv_tcdob_object TYPE tcdob-object.
  DATA lv_cdhdr_object TYPE cdhdr-objectclas.
  DATA lv_existing TYPE ztproc_chdo-objectclas.
  DATA lv_existing_process TYPE ztprocess-process.
  DATA ls_status TYPE ty_status.

  LOOP AT gt_process ASSIGNING FIELD-SYMBOL(<ls_process>).
    CLEAR: lv_existing_process, ls_status.
    ls_status-entity = 'PROCESS'.
    MOVE-CORRESPONDING <ls_process> TO ls_status.

    SELECT SINGLE process
      FROM ztprocess
      WHERE process = @<ls_process>-process
      INTO @lv_existing_process.
    IF sy-subrc = 0.
      ls_status-action = 'Already exists'.
    ELSE.
      INSERT ztprocess FROM @<ls_process>.
      IF sy-subrc = 0.
        ls_status-action = 'Inserted'.
      ELSE.
        ls_status-action = 'Insert failed'.
      ENDIF.
    ENDIF.
    APPEND ls_status TO gt_status.
  ENDLOOP.

  LOOP AT gt_seed ASSIGNING FIELD-SYMBOL(<ls_seed>).
    CLEAR: lv_tcdob_object, lv_cdhdr_object, lv_existing, ls_status.
    ls_status-entity = 'OBJECT'.
    MOVE-CORRESPONDING <ls_seed> TO ls_status.

    SELECT SINGLE object
      FROM tcdob
      WHERE object = @<ls_seed>-objectclas
      INTO @lv_tcdob_object.
    ls_status-in_tcdob = xsdbool( sy-subrc = 0 ).

    SELECT SINGLE objectclas
      FROM cdhdr
      WHERE objectclas = @<ls_seed>-objectclas
      INTO @lv_cdhdr_object.
    ls_status-seen_cdhdr = xsdbool( sy-subrc = 0 ).

    IF ls_status-in_tcdob = abap_false.
      ls_status-action = 'Skipped: not in TCDOB'.
    ELSE.
      SELECT SINGLE objectclas
        FROM ztproc_chdo
        WHERE process = @<ls_seed>-process
          AND objectclas = @<ls_seed>-objectclas
        INTO @lv_existing.

      IF sy-subrc = 0.
        ls_status-action = 'Already exists'.
      ELSE.
        INSERT ztproc_chdo FROM @<ls_seed>.
        IF sy-subrc = 0.
          ls_status-action = 'Inserted'.
        ELSE.
          ls_status-action = 'Insert failed'.
        ENDIF.
      ENDIF.
    ENDIF.

    APPEND ls_status TO gt_status.
  ENDLOOP.

  COMMIT WORK AND WAIT.
ENDFORM.


FORM display_status.
  DATA lo_alv TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_status ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_display_settings( )->set_list_header(
        'Change Log Catalog Seed and Validation' ).
      lo_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
