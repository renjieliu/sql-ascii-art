-- for the best result, make the BMP with size <= 250*250

set nocount on
;
drop table if exists #test_img; 

-- create table #test_img (img varbinary(max) )


-- insert into #test_img (img) 
SELECT img = BulkColumn 
into #test_img
FROM Openrowset( Bulk '/var/opt/mssql/data/myfiles/kobe.bmp', Single_Blob) as img




--drop table if exists #t 

--select img = convert(varchar(max), img, 2)
--into #t
--from #test_img


--; with cte as 
--(select id = 1, curr = left(img, 2 ), re = right(img, len(img)-2) from #t
--	union all 
-- select id+1, curr = left(re, 2), re = right(re, len(re)-2)  from cte 
-- where len(re) > 2
--)
--select id, curr  from cte 
--option (maxrecursion 0 )



declare @img varchar(max) = (select top 1 img = convert(varchar(max), img, 2) from #test_img)

drop table if exists #size

select width =  cast(convert(varbinary, '0x' 
										+ SUBSTRING(@img, 43, 2)
										+ SUBSTRING(@img, 41, 2)
										+ SUBSTRING(@img, 39, 2) 
										+ SUBSTRING(@img, 37, 2) 
							, 1) 
					 as int)
, height = cast(convert(varbinary, '0x' 
										+ SUBSTRING(@img, 51, 2)
										+ SUBSTRING(@img, 49, 2)
										+ SUBSTRING(@img, 47, 2) 
										+ SUBSTRING(@img, 45, 2) 
							, 1) 
					 as int)

into #size 



declare @padding int = ( select iif( 3*width%4 = 0, 0,  4- (3*width%4))  from #size )


drop table if exists #cte

create table #cte (id int, ch varchar(max))

declare @ptr int = 109 
declare @line_id int = 1
declare @width_bytes int = (select (select 3*2*width from #size) + @padding*2)

while @ptr < len(@img)-109
begin 

	insert into #cte 
	select @line_id, SUBSTRING(@img, @ptr, @width_bytes)

	set @line_id = @line_id + 1 
	set @ptr = @ptr + @width_bytes
	--if @id % 10000 = 0
	--begin
	--	select cast(100.0 * @ptr / len(@img) as decimal(38,2))
	--end 

end


--select * from #cte

update #cte set ch = left (ch, len(ch)- @padding*2)



declare @total varchar(max) = (select total = STRING_AGG(ch, '') within group(order by id) from #cte)



declare @total_ptr int = 1 
declare @id int = 1


drop table if exists #staging 

create table #staging (id int, ch varchar(max))


--declare @table table (id int, ch varchar(max))


while @total_ptr < len(@total)
begin 
	insert into #staging -- @table 
	select @id, SUBSTRING(@total, @total_ptr, 2)

	set @id = @id + 1 
	set @total_ptr = @total_ptr+2
	--if @id % 10000 = 0
	--begin
	--select cast(100.0 * @ptr / len(@total) as decimal(38,2))
	--end 
end

--insert into #staging
--select * from @table 

drop table if exists test_img_staging

select * into test_img_staging from #staging 



--select * from test_img_staging
--order by 1 


drop table if exists #pic 

select 
pixel_n = ceiling(id/3.0)
, id
, ch
, pixel_rgb = cast(convert(varbinary, '0x' + ch, 1 ) as int)
into #pic 
from test_img_staging 
order by 1 


--select * from #pic 
--order by id 



drop table if exists #final 

select 
*
, line_n = ceiling(pixel_n / (select width from #size))
, pixel_gray = AVG(pixel_rgb) over(partition by pixel_n)
into #final
from #pic 

-- select * from #final 

set nocount off; 

declare @palette varchar(1000) = '@%=~*-. '
--declare @palette varchar(1000) = '* '
select 
line_n
, string_agg( SUBSTRING( @palette
						, 1+cast( pixel_gray / (255.0 / (len(@palette) ) )   as decimal(5,0))
						, 1)
			 , '')  
   within group (order by pixel_n)
from #final 
--where (id - 54)%3 = 0 
group by line_n
order by 1 desc


