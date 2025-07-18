USE [DWFelsineoE900]
GO
/****** Object:  StoredProcedure [dbo].[Blockchain_Esporta_Dati_FMV_P]    Script Date: 15/06/2021 16:43:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[Blockchain_Esporta_Dati_FMV_P]
( 
	@formatoFile varchar(3) -- inserire CSV o XLS
	,@articoloPF varchar(20)
	,@lottoPF varchar(20)
	,@mp1 as varchar(20) = null -- materia prima 1
	,@mp2 as varchar(20) = null	-- materia prima 2
	,@mp3 as varchar(20) = null	-- materia prima 3
	,@mp4 as varchar(20) = null	-- materia prima 4
	,@mp5 as varchar(20) = null	-- materia prima 5
)
as

insert into DWFelsineoE900.dbo.Blockchain_Storico_FMV
select 
	CONVERT(date, getdate())
	,CodiceArticolo
	,convert(varchar(30),Lotto) as Lotto
	,convert(date,DataScad,103) as DataScad
	,Fase
	,DescrizioneFase
	,convert(date,DataInizio,103) as DataInizio
	,convert(date,DataFine,103) as DataFine
	,FacilityFrom
	,FacilityTo
	,ProductIdInput
	,cast(InputLotNumber as varchar(30)) as InputLotNumber
	,cast(QuantitaInput as int) as QuantitaInput
	,UOMInput
	,ProductIdOutput
	,cast(OutputLotNumber as varchar(30)) as OutputLotNumber
	,cast(QuantitaOutput as int) as QuantitaOutput
	,UOMOutput
from (
-- FASE 99
SELECT
	 ILLITM as CodiceArticolo, ILLOTN as Lotto, convert(datetime,dbo.julianToDate(lotti.IOMMEJ),103) as DataScad, '99' AS Fase ,'Fine caricamento lotto PF' as DescrizioneFase
	 ,null as DataInizio, null as DataFine,0 as FacilityFrom, 0 as FacilityTo, null as ProductIdInput, null as InputLotNumber, '0' as QuantitaInput,null as UOMInput
	 , null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
WHERE
	art.ILLITM = @articoloPF
	AND art.ILLOTN =@lottoPF
	AND art.ILDCT = 'ic'
--
--
-- fase 7 sped-vendita 
UNION
SELECT 
	 ILLITM as CodiceArticolo, ILLOTN as Lotto, convert(datetime,dbo.julianToDate(lotti.IOMMEJ),103) as DataScad, '7' AS Fase ,'Vendita cliente finale - SPEDIZIONE' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(ILTRDJ)),103) as DataInizio,convert(datetime,dbo.julianToDate(max(ILTRDJ)),103) as DataFine,8 as FacilityFrom,99 as FacilityTo
	 ,ILLITM as ProductIdInput, ILLOTN as InputLotNumber, '0' as QuantitaInput,null as UOMInput
	 , null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
WHERE
	ILLITM = @articoloPF
	AND ILLOTN = @lottoPF
	AND ILDCT in ('so','st','s4','sh')
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ
--
--
--
-- fase 6 sped-vendita 
union
SELECT 
	 art.ILLITM as CodiceArticolo, art.ILLOTN as Lotto, convert(datetime,dbo.julianToDate(lotti.IOMMEJ),103) as DataScad, '6' AS Fase ,'Ricezione prodotto affettato - RICEZIONE' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(ILTRDJ)),103) as DataInizio,convert(datetime,dbo.julianToDate(max(ILTRDJ)),103) as DataFine, cast(d.WLVEND as bigint) as FacilityFrom,'8' as FacilityTo
	 ,art.ILLITM as ProductIdInput,art.ILLOTN as InputLotNumber,sum(ILTRQT / 1000) AS QuantitaInput,art.ILTRUM as UOMInput
	 , null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
	inner join JDE_PRODUCTION.PRODDTA.F3112 d on d.WLDOCO = art.ILDOC
WHERE
	art.ILLITM = @articoloPF
	AND art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
	and d.WLVEND != '0'
group by 
	ILLITM , ILLOTN, lotti.IOMMEJ, d.WLVEND,ILTRUM
--
--
--
-- fase 5 affettamento-spedizione
union
SELECT 
	 @articoloPF as CodiceArticolo
	 , mag.ILLOTN as Lotto
	 , (select convert(datetime,dbo.julianToDate(iommej),103) from JDE_PRODUCTION.PRODDTA.F4108 where iolitm = @articoloPF and IOLOTN = mag.ILLOTN) as DataScad
	 , '5' AS Fase 
	 ,'Spedizione semilavorato e affettamento' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(mag.ILTRDJ)),103) as DataInizio
	 ,(select convert(datetime,dbo.julianToDate(iommej),103) from JDE_PRODUCTION.PRODDTA.F4108 where iolitm = @articoloPF and IOLOTN = mag.ILLOTN)-artPF.IMSLD-1 as DataFine
	 ,'8' as FacilityFrom
	 ,cast(cast(ana.ABAN82 as bigint)as varchar(15)) as FacilityTo
	 ,lotti.IOLITM as ProductIdInput
	 , ILLOTN as InputLotNumber
	 ,-1*sum(ILTRQT / 1000) AS QuantitaInput
	 ,ILTRUM as UOMInput
	 , null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 mag
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on mag.ILLOTN = lotti.IOLOTN and mag.ILMCU = lotti.IOMCU
	inner join JDE_PRODUCTION.PRODDTA.F4201 sh on mag.ILKCOO = sh.SHKCOO and mag.ILDOC = sh.SHDOCO and mag.ILDCT = sh.SHDCTO
	inner join JDE_PRODUCTION.PRODDTA.F0101 ana on sh.SHSHAN = ana.ABAN8
	inner join JDE_PRODUCTION.PRODDTA.F4101 artPF on artPF.IMLITM = @articoloPF 
WHERE
	mag.ILLOTN = @lottoPF
	AND mag.ILDCT in ('ST')
	and lotti.IOLITM like 'S%'
group by 
	ILLITM,ILLOTN, convert(datetime,dbo.julianToDate(iommej),103),ILTRUM,lotti.IOLITM,ana.ABAN82
	,artPF.IMSLD
--
--
--
-- fase 4 confezionamento-pastorizzazione-trasformazione
union
SELECT 
	 @articoloPF as CodiceArticolo, art.ILLOTN as Lotto,  (select convert(datetime,dbo.julianToDate(IOMMEJ),103) from JDE_PRODUCTION.PRODDTA.F4108 where IOLITM = @articoloPF and IOLOTN = art.ILLOTN) as DataScad , '4' AS Fase ,'confezionamento-pastorizzazione-trasformazione' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(art.ILTRDJ)),103) as DataInizio,convert(datetime,dbo.julianToDate(max(art.ILTRDJ)),103) as DataFine, '8' as FacilityFrom,'8' as FacilityTo
	 ,tabellaUS.ILLITM as ProductIdInput, tabellaUS.ILLOTN as InputLotNumber,cast(sum(tabellaUS.QTA) as float) AS QuantitaInput,tabellaUS.ILTRUM as UOMInput
	 ,art.ILLITM as ProductIdOutput, art.ILLOTN as OutputLotNumber,sum(art.ILTRQT / 1000) as QuantitaOutput,art.ILTRUM as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
	inner join (
		select ILLITM,ILLOTN,-1*sum(ILTRQT / 1000) as QTA,ILTRUM,ILDOC
		from JDE_PRODUCTION.PRODDTA.F4111 artUS
		WHERE
			artUS.ILLOTN = @lottoPF
			AND artUS.ILDCT in ('IM')
			and artUS.ILLITM like 'US%'
		group by 
			artUS.ILLITM,artUS.ILLOTN,artUS.ILTRUM,artUS.ILDOC
	) as tabellaUS on tabellaUS.ILDOC = art.ILDOC
WHERE
	art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
	and art.ILLITM like 'S%'
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ,art.ILTRUM,
	tabellaUS.ILLITM,tabellaUS.ILLOTN,tabellaUS.ILTRUM
--
--
--
-- fase 3 raffreddam-celle stag.-osservazione
union
SELECT 
	 @articoloPF as CodiceArticolo
	 ,art.ILLOTN as Lotto
	 ,(select convert(datetime,dbo.julianToDate(IOMMEJ),103) from JDE_PRODUCTION.PRODDTA.F4108 where IOLITM = @articoloPF and IOLOTN = art.ILLOTN) as DataScad
	 ,'3' AS Fase 
	 ,'raffreddam-celle stag.-osservazione' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(art.ILTRDJ),103) as DataInizio
	 ,convert(datetime,dbo.julianToDate(lotti.IODLEJ),103) as DataFine -- data fine stagionatura
	 ,'8' as FacilityFrom
	 ,'8' as FacilityTo
	 ,art.ILLITM as ProductIdInput
	 ,art.ILLOTN as InputLotNumber
	 ,sum(art.ILTRQT / 1000) AS QuantitaInput
	 ,art.ILTRUM as UOMInput
	 , null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
WHERE
	art.ILLITM like 'US%'
	AND art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ,art.ILTRUM,lotti.IODLEJ,art.ILTRDJ
--
--
--
-- fase 2 celle lievit-forno cuocitore
union
SELECT 
	 @articoloPF as CodiceArticolo
	 ,art.ILLOTN as Lotto
	 ,(select convert(datetime,dbo.julianToDate(IOMMEJ),103) from JDE_PRODUCTION.PRODDTA.F4108 where iolitm = @articoloPF and IOLOTN = art.ILLOTN) as DataScad
	 ,'2' AS Fase ,'celle lievit-forno cuocitore' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(art.ILTRDJ)),103) as DataInizio
	 ,convert(datetime,dbo.julianToDate(max(art.ILTRDJ)),103) as DataFine
	 ,'8' as FacilityFrom
	 ,'8' as FacilityTo
	 ,tabellaIMP.ILLITM as ProductIdInput
	 ,tabellaIMP.ILLOTN as InputLotNumber
	 ,sum(tabellaIMP.QTA) AS QuantitaInput
	 ,tabellaIMP.ILTRUM as UOMInput
	 ,art.ILLITM as ProductIdOutput, art.ILLOTN as OutputLotNumber, sum(art.ILTRQT / 1000) as QuantitaOutput,art.ILTRUM as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
	inner join (
		select ILLITM,ILLOTN,-1*sum(ILTRQT / 1000) as QTA,ILTRUM,ILDOC
		from JDE_PRODUCTION.PRODDTA.F4111 artUS
		WHERE
			artUS.ILLOTN = @lottoPF
			AND artUS.ILDCT in ('IM')
			and artUS.ILLITM like 'IMP%'
		group by 
			artUS.ILLITM,artUS.ILLOTN,artUS.ILTRUM,artUS.ILDOC
	) as tabellaIMP on tabellaIMP.ILDOC = art.ILDOC
WHERE
	art.ILLITM like 'US%'
	AND art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ,art.ILTRUM,lotti.IODLEJ
	,tabellaIMP.ILLITM,tabellaIMP.ILLOTN,tabellaIMP.ILTRUM
--
--
--
-- fase 1 Dosaggio ingredienti - TRASFORMAZIONE
union
SELECT 
	 @articoloPF as CodiceArticolo
	 ,art.ILLOTN as Lotto
	 ,(select convert(datetime,dbo.julianToDate(IOMMEJ),103) from JDE_PRODUCTION.PRODDTA.F4108 where iolitm = @articoloPF and IOLOTN = art.ILLOTN) as DataScad
	 ,'1' AS Fase 
	 ,'Dosaggio ingredienti - TRASFORMAZIONE' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(art.ILTRDJ)),103) as DataInizio
	 ,convert(datetime,dbo.julianToDate(max(art.ILTRDJ)),103) as DataFine
	 ,'8' as FacilityFrom
	 ,'8' as FacilityTo
	 ,tabellaIMP.ILLITM as ProductIdInput
	 ,tabellaIMP.ILLOTN as InputLotNumber
	 ,ceiling(sum(tabellaIMP.QTA)) AS QuantitaInput
	 ,tabellaIMP.ILTRUM as UOMInput
	 ,art.ILLITM as ProductIdOutput
	 ,art.ILLOTN as OutputLotNumber
	 ,sum(art.ILTRQT / 1000) as QuantitaOutput
	 ,art.ILTRUM as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on art.ILITM = lotti.IOITM and art.ILLOTN = lotti.IOLOTN 
	inner join (
		select ILLITM,ILLOTN,-1*(sum(ILTRQT / 1000)) as QTA,ILTRUM,ILDOC
		from JDE_PRODUCTION.PRODDTA.F4111 artUS
		WHERE
			artUS.ILDCT in ('IM')
			and artUS.ILLITM in  (@mp1,@mp2,@mp3,@mp4,@mp5)
		group by 
			artUS.ILLITM,artUS.ILLOTN,artUS.ILTRUM,artUS.ILDOC
	) as tabellaIMP on tabellaIMP.ILDOC = art.ILDOC
WHERE
	art.ILLITM like 'IMP%'
	AND art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ,art.ILTRUM,lotti.IODLEJ
	,tabellaIMP.ILLITM,tabellaIMP.ILLOTN,tabellaIMP.ILTRUM
--
--
--
-- fase 0 Ricezione materiale acquistato
union
SELECT 
	 tabellaIMP.ILLITM as CodiceArticolo
	 ,tabellaIMP.ILLOTN as Lotto
	 ,(select convert(datetime,dbo.julianToDate(IOMMEJ),103) from JDE_PRODUCTION.PRODDTA.F4108 where iolitm = tabellaIMP.ILLITM and IOLOTN = tabellaIMP.ILLOTN) as DataScad
	 ,'0' AS Fase 
	 ,'Ricezione materiale acquistato' as DescrizioneFase
	 ,convert(datetime,dbo.julianToDate(min(ACQ.ILTRDJ)),103) as DataInizio
	 ,convert(datetime,dbo.julianToDate(max(ACQ.ILTRDJ)),103) as DataFine
	 ,cast(lotti.IOVEND as varchar(30)) as FacilityFrom
	 ,'8' as FacilityTo
	 ,tabellaIMP.ILLITM as ProductIdInput
	 ,lotti.IORLOT as InputLotNumber
	 ,sum(ACQ.QTAAcq) AS QuantitaInput
	 ,ACQ.UMAcq as UOMInput
	 ,null as ProductIdOutput, null as OutputLotNumber, '0' as QuantitaOutput,null as UOMOutput
FROM 
	JDE_PRODUCTION.PRODDTA.F4111 art
	inner join (
		select ILLITM,ILLOTN,-1*sum(ILTRQT / 1000) as QTA,ILTRUM,ILDOC
		from JDE_PRODUCTION.PRODDTA.F4111 artUS
		WHERE
			artUS.ILDCT in ('IM')
			and artUS.ILLITM in (@mp1,@mp2,@mp3,@mp4,@mp5)
		group by 
			artUS.ILLITM,artUS.ILLOTN,artUS.ILTRUM,artUS.ILDOC
	) as tabellaIMP on tabellaIMP.ILDOC = art.ILDOC
	inner join JDE_PRODUCTION.PRODDTA.F4108 lotti on tabellaIMP.ILLITM = lotti.IOLITM and tabellaIMP.ILLOTN = lotti.IOLOTN 
	inner join (
		select 
			(ILTRQT/1000) as QTAAcq 
			,ILTRUM as UMAcq
			,ILLITM,ILLOTN,ILDOCO,ILDCTO,ILTRDJ
		from JDE_PRODUCTION.PRODDTA.F4111 
		where 
			ILDCT like 'O%' and ILTRQT != 0 
	) ACQ on lotti.IOLITM = ACQ.ILLITM 
		and lotti.IOLOTN = ACQ.ILLOTN 
		and lotti.IODOCO = ACQ.ILDOCO 
		and lotti.IODCTO = ACQ.ILDCTO 
WHERE
	art.ILLITM like 'IMP%'
	AND art.ILLOTN = @lottoPF
	AND art.ILDCT in ('IC')
group by 
	art.ILLITM,art.ILLOTN,lotti.IOMMEJ,art.ILTRUM,lotti.IODLEJ,lotti.IOVEND
	,tabellaIMP.ILLITM,tabellaIMP.ILLOTN,tabellaIMP.ILTRUM,IORLOT,ACQ.UMAcq
) as tab

if @formatoFile = 'CSV' 
	EXEC master..xp_cmdshell 
		'bcp DWFelsineoE900.dbo.Blockchain_Storico_FMV out "\\fileserver\batch\Blockchain\Blockchain_FMV.csv" -c -t; -T -S'

if @formatoFile = 'XLS'
	EXEC master..xp_cmdshell 
		'bcp "select CodiceArticolo,Lotto,DataScad,Fase,DescrizioneFase,DataInizio,DataFine,FacilityFrom,FacilityTo,ProductIdInput,InputLotNumber,QuantitaInput,UOMInput,ProductIdOutput,OutputLotNumber,QuantitaOutput,UOMOutput from DWFelsineoE900.dbo.Blockchain_Storico_FMV where DataEsecuzione = convert(date,getdate())" queryout "\\fileserver\batch\Blockchain\Blockchain_FMV.xls" -T -w'

