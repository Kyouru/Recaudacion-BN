DECLARE
	linebuf				VARCHAR2 (1000);
	cRecauda			recaudacionbanco%ROWTYPE;
	vFechapago			VARCHAR2(8);
	vValidaTrama		NUMBER;
	vFechaProceso		DATE:= SYSDATE;
	vNumerocuota		prestamocuotas.numerocuota%TYPE;

	vOrdenCobro			VARCHAR(12); --Variable que retorna, contiene ACT/ATR - Fecha envio (YYYYMMDD)
	vIdentificador		VARCHAR(7) := '0180100'; --Codigo Banco + Cliente

BEGIN
	--variable para probar trama
	linebuf := '';
	
	IF linebuf IS NOT NULL AND SUBSTR(linebuf, 1, LEN(vIdentificador)) = vIdentificador THEN
		SELECT COUNT(*) 
		INTO vValidaTrama 
		FROM RECAUDACIONBANCO
		WHERE REPLACE(TRIM(TRAMA), ' ', '') = REPLACE(TRIM(linebuf), ' ', '');

		IF vValidaTrama = 0 THEN

			cRecauda.trama					:= linebuf;
			cRecauda.fechacarga				:= vFechaProceso;
			cRecauda.usuariocarga			:= USER;
			cRecauda.codigobanco			:= 5;		-- Codigo Banco en Datosbanco -- ScotiaBank

			BEGIN
				cRecauda.periodosolicitud  	:= SUBSTR(linebuf, 1, 4);
				cRecauda.numerosolicitud   	:= SUBSTR(linebuf, 5, 7);

				cRecauda.numerocuota		:= SUBSTR(linebuf, 13, 4);

				--Situacion de pago
				----SUBSTR(linebuf, 17, 2);

				cRecauda.moneda           	:= SUBSTR(linebuf, 19, 1); --1:Soles 2:Dolares

	            cRecauda.codigosocio		:= PKG_PRESTAMO.F_OBT_CODIGOPERSONA(cRecauda.periodosolicitud, cRecauda.numerosolicitud);

				--Nombre Cliente Retorna
				----SUBSTR(linebuf, 20, 60);
				----PKG_PRESTAMO.F_OBT_CODIGOPERSONA(cRecauda.periodosolicitud, cRecauda.numerosolicitud)
				cRecauda.nombrecliente		:= PKG_PERSONA.F_OBT_NOMBRECOMPLETO(cRecauda.codigosocio);

				--Importe Cuota
				cRecauda.importeorigen 		:= TO_NUMBER(SUBSTR(linebuf, 80, 15)) / 100;

				cRecauda.fechavencimiento 	:= TO_DATE 	(
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
				vOrdenCobro = SUBSTR(linebuf, 160, 12);

				cRecauda.tipopago = SUBSTR(vOrdenCobro, 1, 3);
				cRecauda.fechaenvio =  TO_DATE 	(
														SUBSTR(vOrdenCobro, 5, 4)||'-'||
														SUBSTR(vOrdenCobro, 9, 2)||'-'||
														SUBSTR(vOrdenCobro, 11, 2),
														'YYYY-MM-DD'
														);

				--Mora
				----TO_NUMBER(SUBSTR(linebuf, 172, 15)) / 100;
				cRecauda.importemora 		:= 0;

				--Compensacion
				----TO_NUMBER(SUBSTR(linebuf, 187, 15)) / 100;

				--Importe Cobrado
				----cRecauda.importedepositado 	:= TO_NUMBER(SUBSTR(linebuf, 202, 15)) / 100;
				----cRecauda.importedepositado 	:= cRecauda.importeorigen;
				cRecauda.importedepositado 	:= TO_NUMBER(SUBSTR(linebuf, 202, 15)) / 100;
	            
				--Agencia de cobro
				----SUBSTR(linebuf, 217, 4);
				cRecauda.oficinapago 		:= SUBSTR(linebuf, 217, 4);

				cRecauda.fechapago 			:= TO_DATE(
														SUBSTR(linebuf, 221, 4) || '-' ||
														SUBSTR(linebuf, 225, 2) || '-' ||
														SUBSTR(linebuf, 227, 2)
													, 'YYYY-MM-DD'
													);
				
				--Hora Cobro HHMMSS
				cRecauda.referencias      	:= SUBSTR(linebuf, 229, 6);

				--Espacios Vacios
				----SUBSTR(linebuf, 235, 60);

				cRecauda.numerocuentabanco 	:= pkg_datosbanco.f_obt_cuentabancorecauda(cRecauda.codigobanco, cRecauda.moneda);

				--cRecauda.nromovimiento 		:= vNrocli;

				cRecauda.fechaproceso 		:= SYSDATE;
				cRecauda.usuarioproceso 	:= USER;
				BEGIN
					SELECT MIN(numerocuota)
					INTO vNumerocuota
					FROM prestamocuotas 
					WHERE periodosolicitud = cRecauda.periodosolicitud 
					AND numerosolicitud = cRecauda.numerosolicitud 
					AND estado = 2;
				EXCEPTION WHEN OTHERS THEN
					vNumerocuota := NULL;
				END; 

				BEGIN
					PKG_RECAUDACIONBANCO.P_OBT_VERIFICARDEBITOAUTO(cRecauda.periodosolicitud, cRecauda.numerosolicitud, cRecauda.debitoautomatico);
					cRecauda.estado := '1';
				EXCEPTION WHEN OTHERS THEN
					RAISE_APPLICATION_ERROR(-20120,'  cRecauda.estado  ' || cRecauda.estado  );
				END;

				cRecauda.cuotacronograma 	:= vNumerocuota;

				cRecauda.amortizacion   	:= pkg_prestamocuotas.F_OBT_AMORTIZACION ( 	cRecauda.numerosolicitud, 
																						cRecauda.periodosolicitud, 
																						vNumerocuota);

				cRecauda.interes        	:= pkg_prestamocuotas.F_OBT_INTERES ( 		cRecauda.numerosolicitud,
																						cRecauda.periodosolicitud, 
																						vNumerocuota );

				cRecauda.mora           	:= 0;

				cRecauda.reajuste       	:= pkg_prestamocuotas.F_OBT_REAJUSTE (		cRecauda.numerosolicitud, 
																						cRecauda.periodosolicitud, 
																						vNumerocuota);

				cRecauda.portes         	:= pkg_prestamocuotas.F_OBT_PORTES (		cRecauda.numerosolicitud, 
																						cRecauda.periodosolicitud, 
																						vNumerocuota);

				cRecauda.segurointeres  	:= pkg_prestamocuotas.F_OBT_SEGUROINTERES( 	cRecauda.numerosolicitud, 
																						cRecauda.periodosolicitud, 
																						vNumerocuota); 
				cRecauda.totalcuota 		:= 	NVL(cRecauda.amortizacion, 0) +
												NVL(cRecauda.interes, 0) +
												NVL(cRecauda.mora, 0) +
												NVL(cRecauda.reajuste, 0) +
												NVL(cRecauda.portes, 0) +
												NVL(cRecauda.segurointeres, 0);

				cRecauda.importeorigen 		:= 	NVL(cRecauda.amortizacion, 0) +
												NVL(cRecauda.interes, 0) +
												NVL(cRecauda.mora, 0) +
												NVL(cRecauda.reajuste, 0) +
												NVL(cRecauda.portes, 0) +
												NVL(cRecauda.segurointeres, 0);
				--
				IF cRecauda.numerocuota <> cRecauda.cuotacronograma THEN 
					cRecauda.observaciones 	:= cRecauda.observaciones || ' CUOTAS DIFERENTES ' || CHR(9);
				END IF;

				IF cRecauda.importeorigen <> cRecauda.totalcuota THEN
					cRecauda.observaciones 	:= cRecauda.observaciones || ' IMPORTES DIFERENTES ' || CHR(9);
				END IF;

				BEGIN
					INSERT INTO recaudacionbanco( fechacarga,
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
					VALUES ( cRecauda.fechacarga,
					cRecauda.usuariocarga,
					cRecauda.codigosocio,
					cRecauda.nombrecliente,
					cRecauda.referencias,
					cRecauda.importeorigen,
					cRecauda.importedepositado,
					cRecauda.importemora,
					cRecauda.oficinapago,
					cRecauda.nromovimiento,
					cRecauda.fechapago,
					cRecauda.tipopago,
					cRecauda.estado,
					cRecauda.codigobanco,
					cRecauda.numerocuentabanco,
					cRecauda.periodosolicitud,
					cRecauda.numerosolicitud,
					cRecauda.moneda,
					cRecauda.numerocuota,
					cRecauda.fechavencimiento,
					cRecauda.amortizacion,
					cRecauda.interes,
					cRecauda.mora,
					cRecauda.reajuste,
					cRecauda.portes,
					cRecauda.segurointeres,
					cRecauda.fechaproceso,
					cRecauda.usuarioproceso,
					cRecauda.trama,
					cRecauda.fechaenvio,
					cRecauda.debitoautomatico,
					cRecauda.cuotacronograma,
					cRecauda.totalcuota,
					cRecauda.observaciones
					) ;
					COMMIT;
				END;
			END;
		END IF;
	END IF;
END;

SELECT * FROM RECAUDACIONBANCO ORDER BY FECHACARGA DESC;

DELETE FROM RECAUDACIONBANCO WHERE TRAMA = '';