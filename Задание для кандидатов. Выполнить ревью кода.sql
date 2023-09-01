create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	declare 
		@RowCount int = (select count(*) 
			from syn.SA_CustomerSeasonal as cs)
		,@ErrorMessage varchar(8000)

	-- Проверка на корректность загрузки
	if not exists (
		select 1
		from syn.ImportFile as imf
		where imf.ID = @ID_Record
		and imf.FlagLoaded = cast(1 as bit)
	)
	begin
		set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

		raiserror(@ErrorMessage, 3, 1)

		return
	end

	create table #ProcessedRows (
		ActionType varchar(255),
		ID int
	)

	-- Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	from syn.SA_CustomerSeasonal as cs
		inner join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		inner join dbo.Season as s on s.Name = cs.Season
		inner join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		inner join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, cast(0 as bit)) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		cs.*
		,case
			when cc.ID is null 
				then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null 
				then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null 
				then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null 
				then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, cast(0 as bit)) as bit) is null
				then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
		left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		left join dbo.Season as s on s.Name = cs.Season
		left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, cast(0 as bit)) as bit) is null
end