USE [DWFelsineoE900]
GO
/****** Object:  StoredProcedure [dbo].[Blockchain_Procedura_P]    Script Date: 15/06/2021 16:06:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER proc [dbo].[Blockchain_Procedura_P]
as
-- controllo se esistono record per oggi:
-- se non esistono esco, altrimenti procedo
if not exists(
	select 
		bc.Company
		,ILLITM
		,ILLOTN 
		,bc.ComponenteMP1
		,bc.ComponenteMP2
		,bc.ComponenteMP3
		,bc.ComponenteMP4
		,bc.ComponenteMP5
		,dbo.juliantodate(min(ILTRDJ)) as datalotto
	from JDE_PRODUCTION.PRODDTA.f4111 art
		inner join DWFelsineoE900.dbo.Blockchain_Articoli_abilitati bc 
			on art.ILMCU = BC.mcu and art.ILKCOO = BC.company and art.ILLITM = bc.ArticoloPF
	where ILDCT like 's%'
	and ILTRDJ > 121000
	group by bc.Company,ILLITM,ILLOTN
		,bc.ComponenteMP1
		,bc.ComponenteMP2
		,bc.ComponenteMP3
		,bc.ComponenteMP4
		,bc.ComponenteMP5
	having  min(ILTRDJ) = dbo.DateToJulian(GETDATE()) 
)
return;

declare @numRighe int
-- procedo poiché ho trovato dei record per la giornata di oggi
-- quindi salvo le informazioni in una tabella temporanea sulla quale effettuerò il ciclo
-- di chiamate alle stored procedure
IF OBJECT_ID('tempdb..#tempTBLCiclo') IS NOT NULL drop table #tempTBLCiclo;
select 
	bc.Company
	,ILLITM
	,ILLOTN 
	,bc.ComponenteMP1
	,bc.ComponenteMP2
	,bc.ComponenteMP3
	,bc.ComponenteMP4
	,bc.ComponenteMP5
	,dbo.juliantodate(min(ILTRDJ)) as datalotto
into #tempTBLCiclo
from JDE_PRODUCTION.PRODDTA.f4111 art
	inner join DWFelsineoE900.dbo.Blockchain_Articoli_abilitati bc 
		on art.ILMCU = BC.mcu and art.ILKCOO = BC.company and art.ILLITM = bc.ArticoloPF
where 
	ILDCT like 's%'
	and ILTRDJ > 121000
group by 
	bc.Company,ILLITM,ILLOTN
	,bc.ComponenteMP1
	,bc.ComponenteMP2
	,bc.ComponenteMP3
	,bc.ComponenteMP4
	,bc.ComponenteMP5
having  min(ILTRDJ) = dbo.DateToJulian(GETDATE()) 

-- conto le righe salvate nella tabella temporanea per inizializzare il contatore
set @numRighe = @@rowcount

-- dichiaro le variabili da passare alle stored procedure come parametri
declare @Societa varchar(5),@articoloPF varchar(20),@Lotto varchar(20)
,@ComponenteMP1 varchar(20),@ComponenteMP2 varchar(20),@ComponenteMP3 varchar(20),@ComponenteMP4 varchar(20),@ComponenteMP5 varchar(20)

-- inizio a ciclare:
-- per ciascuna riga della tabella temporanea leggo i valori dei campi, me li salvo nelle variabili temporanee
-- poi chiamo la stored procedure dedicata in base alla Società/Company passandole come parametri le variabili suddette
-- infine, dopo aver chiamato le stored, cancello la riga processata e decremento l'iteratore, così vado avanti coi successivi cicli
while @numRighe > 0
begin 
	select top 1  
		@Societa = Company
		,@articoloPF = ILLITM
		,@Lotto = ILLOTN
		,@ComponenteMP1 = ComponenteMP1
		,@ComponenteMP2	= ComponenteMP2
		,@ComponenteMP3	= ComponenteMP3
		,@ComponenteMP4	= ComponenteMP4
		,@ComponenteMP5	= ComponenteMP5
	from #tempTBLCiclo
	
	if (@Societa = '00001')
		exec DWFelsineoE900.dbo.Blockchain_Esporta_Dati_FELS_P 
			@formatoFile = 'XLS'
			,@articoloPF = @articoloPF
			,@lottoPF = @Lotto
			,@mp1 = @ComponenteMP1
			,@mp2 = @ComponenteMP2
			,@mp3 = @ComponenteMP3
			,@mp4 = @ComponenteMP4
			,@mp5 = @ComponenteMP5

	if (@Societa = '00008')
		exec DWFelsineoE900.dbo.Blockchain_Esporta_Dati_FMV_P
			@formatoFile = 'XLS'
			,@articoloPF = @articoloPF
			,@lottoPF = @Lotto
			,@mp1 = @ComponenteMP1
			,@mp2 = @ComponenteMP2
			,@mp3 = @ComponenteMP3
			,@mp4 = @ComponenteMP4
			,@mp5 = @ComponenteMP5

	delete top (1) from #tempTBLCiclo
	set @numRighe -= 1
end
