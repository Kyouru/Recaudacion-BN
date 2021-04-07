/*PROCEDURE P_GEN_CARGABANCONACION ( PIDirectorio    VARCHAR2,
                            PINombreArchivo VARCHAR2,
                            PIFechaProceso IN DATE:=SYSDATE
                          ) IS
*/
DECLARE
    linebuf             VARCHAR2(1000);
    vRecauda            recaudacionbanco%ROWTYPE;
    vValidaTrama        NUMBER;
    cFechaProceso       DATE                := SYSDATE;
    vNumerocuota        prestamocuotas.numerocuota%TYPE;

    vOrdenCobro         VARCHAR(12);                        --Variable que retorna, contiene ACT/ATR - Fecha envio (YYYYMMDD)
    cIdentificador      VARCHAR(7)          := '0180100';   --Codigo Banco + Cliente

BEGIN
    --Variable para probar trama
    linebuf := '0202001807460008021C Y T REPRESENTACIONES S.A.                          221032600000000010130420210313000000000000000000000000000000000000000000000000068385520000000000000000000000000000000000000000000000000000101304000520210326164010';
    
    /*in_file := UTL_FILE.FOPEN( PIDirectorio, PINombreArchivo, 'r');
    
    LOOP
        UTL_FILE.GET_LINE (in_file, linebuf);
        
        linebuf := trim(linebuf);
        IF linebuf IS NOT NULL AND SUBSTR(linebuf, 1, LENGTH(cIdentificador)) = cIdentificador THEN
        */
            SELECT COUNT(*)
            INTO vValidaTrama
            FROM recaudacionbanco
            WHERE REPLACE(TRIM(trama), ' ', '') =  REPLACE(TRIM(linebuf), ' ', '');

            IF vValidaTrama = 0 THEN

                vRecauda.trama                  := linebuf;
                vRecauda.fechacarga             := cFechaProceso;
                vRecauda.usuariocarga           := USER;
                vRecauda.codigobanco            := 5;        -- Codigo Banco en Datosbanco -- Scotiabank

                BEGIN
                    vRecauda.periodosolicitud   := SUBSTR(linebuf, 2, 4);
                    vRecauda.numerosolicitud    := TO_NUMBER(SUBSTR(linebuf, 6, 7));

                    vRecauda.numerocuota        := SUBSTR(linebuf, 13, 4);

                    --Situacion de pago
                    ----SUBSTR(linebuf, 17, 2);

                    vRecauda.moneda             := SUBSTR(linebuf, 19, 1); --1:Soles 2:Dolares

                    vRecauda.codigosocio        := PKG_PERSONA.F_OBT_CIP(PKG_PRESTAMO.F_OBT_CODIGOPERSONA(vRecauda.numerosolicitud, vRecauda.periodosolicitud));

                    --Nombre Cliente Retorna
                    ----SUBSTR(linebuf, 20, 60);
                    ----PKG_PRESTAMO.F_OBT_CODIGOPERSONA(vRecauda.periodosolicitud, vRecauda.numerosolicitud)
                    vRecauda.nombrecliente      := PKG_PERSONA.F_OBT_NOMBRECOMPLETO(PKG_PRESTAMO.F_OBT_CODIGOPERSONA(vRecauda.numerosolicitud, vRecauda.periodosolicitud));

                    --Importe Cuota
                    vRecauda.importeorigen      := TO_NUMBER(SUBSTR(linebuf, 80, 15)) / 100;

                    vRecauda.fechavencimiento   := TO_DATE  (
                                                            SUBSTR(linebuf, 95, 4)||'-'||
                                                            SUBSTR(linebuf, 99, 2)||'-'||
                                                            SUBSTR(linebuf, 101, 2),
                                                            'YYYY-MM-DD'
                                                            );

                    --Indicador de la Tasa
                    ----SUBSTR(linebuf, 103, 1);

                    --Factor Mora
                    ----TO_NUMBER(SUBSTR(linebuf, 104, 15)) / 100;

                    --Factor Compensatorio
                    ----TO_NUMBER(SUBSTR(linebuf, 119, 15)) / 100;

                    --Importe Gastos
                    ----TO_NUMBER(SUBSTR(linebuf, 134, 15)) / 100;

                    --Cuenta Cliente
                    ----SUBSTR(linebuf, 149, 11);

                    --Orden Cobro. Variable que retorna, contiene ACT/ATR - Fecha envio (YYYYMMDD)
                    --vOrdenCobro                 := SUBSTR(linebuf, 160, 12);
                    vOrdenCobro                 := '00000' || SUBSTR(linebuf, 73, 7);

                    /*vRecauda.tipopago           := 'ATR';
                    vRecauda.fechaenvio         := TO_DATE   ('2021-03-26',
                                                            'YYYY-MM-DD'
                                                            );
                    */
                    vRecauda.tipopago           :=  CASE SUBSTR(vOrdenCobro, 6, 1)
                                                        WHEN 1 THEN
                                                            'ACT'
                                                        WHEN 2 THEN
                                                            'ATR'
                                                    END;
                    vRecauda.fechaenvio         :=  TO_DATE   (
                                                            SUBSTR(vOrdenCobro, 7, 2)||'-'||
                                                            SUBSTR(vOrdenCobro, 9, 2)||'-'||
                                                            SUBSTR(vOrdenCobro, 11, 2),
                                                            'YY-MM-DD'
                                                            );

                    --Mora
                    ----TO_NUMBER(SUBSTR(linebuf, 172, 15)) / 100;
                    vRecauda.importemora        := 0;

                    --Compensacion
                    ----TO_NUMBER(SUBSTR(linebuf, 187, 15)) / 100;

                    --Importe Cobrado
                    vRecauda.importedepositado  := TO_NUMBER(SUBSTR(linebuf, 202, 15)) / 100;

                    --Agencia de cobro
                    ----SUBSTR(linebuf, 217, 4);
                    vRecauda.oficinapago        := SUBSTR(linebuf, 217, 4);

                    vRecauda.fechapago          := TO_DATE  (
                                                            SUBSTR(linebuf, 221, 4) || '-' ||
                                                            SUBSTR(linebuf, 225, 2) || '-' ||
                                                            SUBSTR(linebuf, 227, 2)
                                                            , 'YYYY-MM-DD'
                                                            );
                    
                    --Hora Cobro HHMMSS
                    vRecauda.nromovimiento      := SUBSTR(linebuf, 229, 6);

                    vRecauda.referencias        := vRecauda.codigosocio||vRecauda.tipopago||vRecauda.nromovimiento;

                    --Espacios Vacios
                    ----SUBSTR(linebuf, 235, 60);

                    vRecauda.numerocuentabanco  := PKG_DATOSBANCO.F_OBT_CUENTABANCORECAUDA(vRecauda.codigobanco, vRecauda.moneda);

                    DBMS_OUTPUT.PUT_LINE(vRecauda.periodosolicitud || '-' || vRecauda.numerosolicitud);

                    BEGIN
                        PKG_RECAUDACIONBANCO.P_OBT_VERIFICARDEBITOAUTO(vRecauda.periodosolicitud, vRecauda.numerosolicitud, vRecauda.debitoautomatico);
                        vRecauda.estado := '1';
                    EXCEPTION WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20120,'  vRecauda.estado  ' || vRecauda.estado  );
                    END;

                    IF vRecauda.tipopago = 'ACT' THEN
                        BEGIN
                            SELECT MIN(numerocuota)
                                INTO vNumerocuota
                                FROM prestamocuotas 
                            WHERE periodosolicitud = vRecauda.periodosolicitud 
                                AND numerosolicitud =  vRecauda.numerosolicitud 
                                AND estado = 2;
                        EXCEPTION WHEN OTHERS THEN
                           vNumerocuota := NULL;       
                    END; 
                    --
                    vRecauda.cuotacronograma := vNumerocuota;
                    --
                    vRecauda.amortizacion   := PKG_PRESTAMOCUOTAS.F_OBT_AMORTIZACION(   vRecauda.numerosolicitud, 
                                                                                        vRecauda.periodosolicitud, 
                                                                                        vNumerocuota);
                    --
                    vRecauda.interes        := PKG_PRESTAMOCUOTAS.F_OBT_INTERES(    vRecauda.numerosolicitud,
                                                                                    vRecauda.periodosolicitud, 
                                                                                    vNumerocuota );
                    vRecauda.mora           := 0;
                    -- 
                    vRecauda.reajuste       := PKG_PRESTAMOCUOTAS.F_OBT_REAJUSTE(   vRecauda.numerosolicitud, 
                                                                                    vRecauda.periodosolicitud, 
                                                                                    vNumerocuota);
                    -- 
                    vRecauda.portes         := PKG_PRESTAMOCUOTAS.F_OBT_PORTES(     vRecauda.numerosolicitud, 
                                                                                    vRecauda.periodosolicitud, 
                                                                                    vNumerocuota);
                    --
                    vRecauda.segurointeres  := PKG_PRESTAMOCUOTAS.F_OBT_SEGUROINTERES(  vRecauda.numerosolicitud, 
                                                                                        vRecauda.periodosolicitud, 
                                                                                        vNumerocuota); 
                     
                    ELSIF vRecauda.tipopago = 'ATR' THEN
                            SELECT SUM(SALDOCAPITAL)
                            INTO vRecauda.amortizacion
                            FROM TABLE( CRE08070.DEUDACUOTASSIP(    vRecauda.periodosolicitud, 
                                                                    vRecauda.numerosolicitud, 
                                                                    vRecauda.fechaenvio ) ) 
                            WHERE FECHAVENCIMIENTO <= vRecauda.fechaenvio
                            AND (SALDOCAPITAL+SALDOINTERES+SALDOMORA)>0;
                            --                                                         
                            vRecauda.interes         := PKG_RECAUDACIONBANCO.F_OBT_SALDOINTERES(    vRecauda.periodosolicitud, 
                                                                                                    vRecauda.numerosolicitud, 
                                                                                                    vRecauda.fechaenvio );
                            --
                            vRecauda.mora            := PKG_RECAUDACIONBANCO.F_OBT_SALDOMORA(   vRecauda.periodosolicitud, 
                                                                                                vRecauda.numerosolicitud, 
                                                                                                vRecauda.fechaenvio );
                            --
                            vRecauda.reajuste       := PKG_RECAUDACIONBANCO.F_OBT_SALDOREAJUSTE(    vRecauda.periodosolicitud, 
                                                                                                    vRecauda.numerosolicitud, 
                                                                                                    vRecauda.fechaenvio );
                            -- 
                            vRecauda.portes         := PKG_RECAUDACIONBANCO.F_OBT_SALDOPORTES(  vRecauda.periodosolicitud, 
                                                                                                vRecauda.numerosolicitud, 
                                                                                                vRecauda.fechaenvio );
                            --
                            vRecauda.segurointeres  := PKG_RECAUDACIONBANCO.F_OBT_SALDOSEGUROINTERES(   vRecauda.periodosolicitud, 
                                                                                                        vRecauda.numerosolicitud, 
                                                                                                        vRecauda.fechaenvio );
                    END IF;

                    vRecauda.totalcuota         :=  NVL(vRecauda.amortizacion, 0) +
                                                    NVL(vRecauda.interes, 0) +
                                                    NVL(vRecauda.mora, 0) +
                                                    NVL(vRecauda.reajuste, 0) +
                                                    NVL(vRecauda.portes, 0) +
                                                    NVL(vRecauda.segurointeres, 0);
                    --
                    IF vRecauda.numerocuota <> vRecauda.cuotacronograma THEN
                        vRecauda.observaciones     := vRecauda.observaciones || ' CUOTAS DIFERENTES ' || CHR(9);
                    END IF;

                    IF vRecauda.importeorigen <> vRecauda.totalcuota THEN
                        vRecauda.observaciones     := vRecauda.observaciones || ' IMPORTES DIFERENTES ' || CHR(9);
                    END IF;

                    BEGIN
                        INSERT INTO recaudacionbanco(   fechacarga,
                                                        usuariocarga,
                                                        codigosocio,
                                                        nombrecliente,
                                                        referencias,
                                                        importeorigen,
                                                        importedepositado,
                                                        importemora,
                                                        oficinapago,
                                                        nromovimiento,
                                                        fechapago,
                                                        tipopago,
                                                        estado,
                                                        codigobanco,
                                                        numerocuentabanco,
                                                        periodosolicitud,
                                                        numerosolicitud,
                                                        moneda,
                                                        numerocuota,
                                                        fechavencimiento,
                                                        amortizacion,
                                                        interes,
                                                        mora,
                                                        reajuste,
                                                        portes,
                                                        segurointeres,
                                                        fechaproceso,
                                                        usuarioproceso,
                                                        trama,
                                                        fechaenvio,
                                                        debitoautomatico,
                                                        cuotacronograma,
                                                        totalcuota,
                                                        observaciones
                                                    )
                            VALUES (    vRecauda.fechacarga,
                                        vRecauda.usuariocarga,
                                        vRecauda.codigosocio,
                                        vRecauda.nombrecliente,
                                        vRecauda.referencias,
                                        vRecauda.importeorigen,
                                        vRecauda.importedepositado,
                                        vRecauda.importemora,
                                        vRecauda.oficinapago,
                                        vRecauda.nromovimiento,
                                        vRecauda.fechapago,
                                        vRecauda.tipopago,
                                        vRecauda.estado,
                                        vRecauda.codigobanco,
                                        vRecauda.numerocuentabanco,
                                        vRecauda.periodosolicitud,
                                        vRecauda.numerosolicitud,
                                        vRecauda.moneda,
                                        vRecauda.numerocuota,
                                        vRecauda.fechavencimiento,
                                        vRecauda.amortizacion,
                                        vRecauda.interes,
                                        vRecauda.mora,
                                        vRecauda.reajuste,
                                        vRecauda.portes,
                                        vRecauda.segurointeres,
                                        vRecauda.fechaproceso,
                                        vRecauda.usuarioproceso,
                                        vRecauda.trama,
                                        vRecauda.fechaenvio,
                                        vRecauda.debitoautomatico,
                                        vRecauda.cuotacronograma,
                                        vRecauda.totalcuota,
                                        vRecauda.observaciones
                                    );
                        COMMIT;
                    END;
                END;
            END IF;
       /* END IF;
    END LOOP;

  EXCEPTION WHEN NO_DATA_FOUND THEN
      UTL_FILE.FCLOSE (in_file);
  WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20300,'Error CargaLiquidacion: '||SQLERRM);

  UTL_FILE.FCLOSE (in_file);*/
END P_GEN_CARGABANCONACION;