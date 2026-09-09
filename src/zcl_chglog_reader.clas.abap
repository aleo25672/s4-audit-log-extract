CLASS zcl_chglog_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_process TYPE c LENGTH 3.
    TYPES ty_date_range TYPE RANGE OF cdhdr-udate.
    TYPES ty_time_range TYPE RANGE OF cdhdr-utime.
    TYPES ty_user_range TYPE RANGE OF cdhdr-username.
    TYPES ty_objectid_range TYPE RANGE OF cdhdr-objectid.

    TYPES:
      BEGIN OF ty_result,
        process     TYPE ty_process,
        objectclas  TYPE cdhdr-objectclas,
        objdescr    TYPE c LENGTH 40,
        objectid    TYPE cdhdr-objectid,
        changenr    TYPE cdhdr-changenr,
        udate       TYPE cdhdr-udate,
        utime       TYPE cdhdr-utime,
        username    TYPE cdhdr-username,
        tcode       TYPE cdhdr-tcode,
        chngind     TYPE cdshw-chngind,
        tabname     TYPE cdshw-tabname,
        tabkey      TYPE cdshw-tabkey,
        fname       TYPE cdshw-fname,
        value_old   TYPE cdshw-f_old,
        value_new   TYPE cdshw-f_new,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    METHODS read
      IMPORTING
        iv_process     TYPE ty_process
        it_date        TYPE ty_date_range
        it_time        TYPE ty_time_range OPTIONAL
        it_user        TYPE ty_user_range OPTIONAL
        it_objectid    TYPE ty_objectid_range OPTIONAL
        iv_max_rows    TYPE i DEFAULT 10000
      EXPORTING
        et_result      TYPE tt_result
        ev_truncated   TYPE abap_bool
        ev_error       TYPE string.

  PRIVATE SECTION.
    METHODS get_date_bounds
      IMPORTING
        it_date        TYPE ty_date_range
      EXPORTING
        ev_date_from   TYPE cdhdr-udate
        ev_date_to     TYPE cdhdr-udate.
ENDCLASS.


CLASS zcl_chglog_reader IMPLEMENTATION.
  METHOD get_date_bounds.
    DATA lv_found TYPE abap_bool.
    DATA lv_low TYPE cdhdr-udate.
    DATA lv_high TYPE cdhdr-udate.

    ev_date_from = '99991231'.
    ev_date_to = '00010101'.

    LOOP AT it_date ASSIGNING FIELD-SYMBOL(<ls_date>) WHERE sign = 'I'.
      CLEAR: lv_low, lv_high.

      CASE <ls_date>-option.
        WHEN 'EQ'.
          lv_low = <ls_date>-low.
          lv_high = <ls_date>-low.
        WHEN 'BT'.
          lv_low = <ls_date>-low.
          lv_high = <ls_date>-high.
        WHEN 'GE' OR 'GT'.
          lv_low = <ls_date>-low.
          lv_high = '99991231'.
        WHEN 'LE' OR 'LT'.
          lv_low = '00010101'.
          lv_high = <ls_date>-low.
        WHEN OTHERS.
          ev_date_from = '00010101'.
          ev_date_to = '99991231'.
          RETURN.
      ENDCASE.

      IF lv_low IS INITIAL.
        lv_low = '00010101'.
      ENDIF.
      IF lv_high IS INITIAL.
        lv_high = '99991231'.
      ENDIF.

      IF lv_low < ev_date_from.
        ev_date_from = lv_low.
      ENDIF.
      IF lv_high > ev_date_to.
        ev_date_to = lv_high.
      ENDIF.
      lv_found = abap_true.
    ENDLOOP.

    IF lv_found = abap_false.
      " A range containing exclusions only means all values except those exclusions.
      ev_date_from = '00010101'.
      ev_date_to = '99991231'.
    ENDIF.
  ENDMETHOD.

  METHOD read.
    DATA lt_catalog TYPE STANDARD TABLE OF ztproc_chdo WITH EMPTY KEY.
    DATA lt_headers TYPE STANDARD TABLE OF cdhdr WITH EMPTY KEY.
    DATA lt_items TYPE STANDARD TABLE OF cdshw WITH EMPTY KEY.
    DATA lv_date_from TYPE cdhdr-udate.
    DATA lv_date_to TYPE cdhdr-udate.

    CLEAR: et_result, ev_truncated, ev_error.

    IF iv_process IS INITIAL.
      ev_error = 'Select a business process.'.
      RETURN.
    ENDIF.
    IF it_date IS INITIAL.
      ev_error = 'Enter at least one date selection.'.
      RETURN.
    ENDIF.
    IF iv_max_rows < 0.
      ev_error = 'Max rows cannot be negative.'.
      RETURN.
    ENDIF.

    SELECT *
      FROM ztproc_chdo
      WHERE process = @iv_process
        AND active = @abap_true
      ORDER BY seq, objectclas
      INTO TABLE @lt_catalog.

    IF lt_catalog IS INITIAL.
      ev_error = |No active object classes are configured for process { iv_process }.|.
      RETURN.
    ENDIF.

    get_date_bounds(
      EXPORTING
        it_date = it_date
      IMPORTING
        ev_date_from = lv_date_from
        ev_date_to = lv_date_to ).

    LOOP AT lt_catalog ASSIGNING FIELD-SYMBOL(<ls_catalog>).
      CLEAR lt_headers.

      CALL FUNCTION 'CHANGEDOCUMENT_READ_HEADERS'
        EXPORTING
          date_of_change            = lv_date_from
          objectclass               = <ls_catalog>-objectclas
          time_of_change            = '000000'
          date_until                = lv_date_to
          time_until                = '235959'
          read_changedocu           = abap_false
        TABLES
          i_cdhdr                   = lt_headers
        EXCEPTIONS
          no_position_found         = 1
          wrong_access_to_archive   = 2
          time_zone_conversion_error = 3
          OTHERS                    = 4.

      IF sy-subrc = 1.
        CONTINUE.
      ELSEIF sy-subrc <> 0.
        ev_error = |Could not read headers for { <ls_catalog>-objectclas } (return code { sy-subrc }).|.
        RETURN.
      ENDIF.

      LOOP AT lt_headers ASSIGNING FIELD-SYMBOL(<ls_header>).
        IF <ls_header>-udate NOT IN it_date.
          CONTINUE.
        ENDIF.
        IF it_time IS NOT INITIAL AND <ls_header>-utime NOT IN it_time.
          CONTINUE.
        ENDIF.
        IF it_user IS NOT INITIAL AND <ls_header>-username NOT IN it_user.
          CONTINUE.
        ENDIF.
        IF it_objectid IS NOT INITIAL AND <ls_header>-objectid NOT IN it_objectid.
          CONTINUE.
        ENDIF.

        CLEAR lt_items.
        CALL FUNCTION 'CHANGEDOCUMENT_READ_POSITIONS'
          EXPORTING
            changenumber           = <ls_header>-changenr
          TABLES
            editpos                = lt_items
          EXCEPTIONS
            no_position_found      = 1
            wrong_access_to_archive = 2
            OTHERS                 = 3.

        IF sy-subrc = 1.
          CONTINUE.
        ELSEIF sy-subrc <> 0.
          ev_error = |Could not read positions for change { <ls_header>-changenr } (return code { sy-subrc }).|.
          RETURN.
        ENDIF.

        LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
          APPEND VALUE #(
            process    = <ls_catalog>-process
            objectclas = <ls_header>-objectclas
            objdescr   = <ls_catalog>-descr
            objectid   = <ls_header>-objectid
            changenr   = <ls_header>-changenr
            udate      = <ls_header>-udate
            utime      = <ls_header>-utime
            username   = <ls_header>-username
            tcode      = <ls_header>-tcode
            chngind    = <ls_item>-chngind
            tabname    = <ls_item>-tabname
            tabkey     = <ls_item>-tabkey
            fname      = <ls_item>-fname
            value_old  = <ls_item>-f_old
            value_new  = <ls_item>-f_new ) TO et_result.

          IF iv_max_rows > 0 AND lines( et_result ) >= iv_max_rows.
            ev_truncated = abap_true.
            RETURN.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
