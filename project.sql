-- Usar a DataBase --

USE imdbdatabase;

-- Atores Mirins vs Atores Adultos --

select count(primaryName) as Count,
case
    when deathYear is not null then 'Deceased'
    when (COALESCE(deathYear, 2024) - birthYear) between 0 and 18 then 'Child Actor'
    when (COALESCE(deathYear, 2024) - birthYear) between 18 and 59 then 'Adult'
    when (COALESCE(deathYear, 2024) - birthYear) >= 60 then 'Elder'
    end as Age_Range
from name_basics
where primaryProfession like "%actress%" or primaryProfession like "%actor%"
group by Age_Range
having Age_Range is not null;

-- TOP 25 mais bem avaliados na IMDB --

select * from (select title, averageRating, numVotes
from titles_akas ta inner join titles_ratings tr on ta.titleId = tr.tconst
inner join titles_basics tb on tr.tconst = tb.tconst
where ordering = 1 and titleType in ("movie","tvmovie")
order by tr.numVotes desc, tr.averageRating desc
limit 25) as progress
order by averageRating desc;

-- Gêneros mais promissores para Séries e Mini-Séries --

-- Query to get count of titles by first genre
SELECT COUNT(*) AS Count,
       SUBSTRING_INDEX(genres, ',', 1) AS Genres
FROM titles_basics
WHERE endYear >= 2024
  AND Genres IS NOT NULL
GROUP BY SUBSTRING_INDEX(genres, ',', 1)

UNION ALL

-- Query to calculate sum of all counts
SELECT SUM(Count) AS Count, 'Total' AS Genres
FROM (
  SELECT COUNT(*) AS Count
  FROM titles_basics
  WHERE endYear >= 2024
    AND Genres IS NOT NULL
) AS total_count

ORDER BY Genres <> 'Total', Count DESC;


-- Séries e Mini-Séries mais antigas do IMDB --

select primaryTitle, (endYear - startYear) as years_since_start from titles_basics
where (endYear - startYear) is not null
and endYear >= 2024
order by years_since_start desc
limit 25;

-- Quem são as pessoas com maior número de créditos no IMDB (35 minutes to run) --

with cte as (select tconst,nconst from titles_principals),

cte1 as (select tconst, cte.nconst, primaryName from
cte inner join name_basics on cte.nconst = name_basics.nconst
order by tconst)

select count(*) Count,
primaryName from cte1
group by primaryName;

-- Proporção de Curtas vs Longa Metragens ao longo dos Anos --

select startYear,
    count(case when titleType = 'movie' then primaryTitle end) as count_movies,
    count(case when titleType = 'short' then primaryTitle end) as count_shorts
from titles_basics
WHERE titleType in ('movie', 'short') and startYear IS NOT NULL
and startYear < 2024
group by startYear
order by startYear DESC;

-- Homens vs Mulheres na Indústria do Entretenimento ao longo dos anos --

select startYear, category, count(*) as Count from
titles_principals as tp inner join titles_basics tb on tp.tconst = tb.tconst
where category = "actor" or category = "actress"
group by startYear, category
order by startYear desc, Count desc;

-- Regiões do Mundo com Mais e Menos filmes Portados --

select region, count(*) as Count from titles_akas
where ordering != "1"
group by region
order by Count desc;

-- Relação entre o tempo de exibição x avaliação da crítica nos Filmes durante os Anos --

select avg(runtimeMinutes) as Minutes, round(averageRating) as Rating, startYear
from titles_basics tb
inner join titles_ratings tr on tb.tconst = tr.tconst
where runtimeMinutes is not null and titleType in ("movie","tvmovie")
group by round(averageRating), startYear
order by startYear desc, Rating desc;

/*
   Agora usando também
    o TMDB_database
*/

-- Lucros por Anos na Indústria de Filmes --

select sum(revenue-budget) as profit, startYear as Launch_Year
from tmdb_movies tm inner join titles_basics tb on tm.imdb_id = tb.tconst
where imdb_id like "tt%" and revenue != 0 and budget != 0
group by startYear
order by Launch_Year desc;

-- Ganhos Brutos por Empresas ao longo dos Anos --

with cte2 as (select distinct substring_index(production_companies,",",1) as Company,
year(release_date) as Year,
sum(revenue) over (partition by substring_index(production_companies,",",1)
order by year(release_date)) as Cumulative_Revenue,
sum(budget) over (partition by substring_index(production_companies,",",1)
order by year(release_date)) as Cumulative_Budget,
sum(revenue-budget) over (partition by substring_index(production_companies,",",1)
order by year(release_date)) as Cumulative_Real
from tmdb_movies
where revenue is not null),

cte3 as (select distinct count(*) as Count,substring_index(production_companies,",",1) as Company from tmdb_movies
         where imdb_id like "tt%"
         group by substring_index(production_companies,",",1)
         order by Count desc
         limit 100 offset 1)

select distinct * from cte2
where Company in (select Company from cte3)
and (Cumulative_Revenue != 0 and Cumulative_Budget != 0);

-- Relação de Lucros em termos Geográficos --

select distinct substring_index(production_countries,",",1) as Country_Name,
sum(revenue-budget) over (partition by substring_index(production_countries,",",1)) as Profits
from tmdb_movies
where imdb_id like "tt%" and revenue != 0 and budget != 0
and substring_index(production_countries,",",1) != ""
order by Country_Name ASC;

-- Projeção de Lucros por Gênero de Filme --

select sum(revenue) as Revenue,substring_index(tm.genres,",",1) as Genres, round(avg(averageRating),2) as Rating
from tmdb_movies tm inner join titles_basics tb on tm.imdb_id = tb.tconst
inner join titles_ratings tr on tb.tconst = tr.tconst
where substring_index(tm.genres,",",1) != "" and titleType in ("movie","tvmovie")
group by substring_index(tm.genres,",",1)
order by Revenue desc;

-- Tendências de Gênero ao Longo do Tempo --

SELECT startYear,
       SUBSTRING_INDEX(tb.genres, ',', 1) AS genre,
       COUNT(*) AS movie_count
FROM titles_basics
WHERE titleType = 'movie'
      AND startYear IS NOT NULL
      AND startYear < 2024
GROUP BY startYear, genre
ORDER BY startYear DESC, movie_count DESC;

select count(distinct region) from titles_akas

-- asdad --
select primaryTitle, averageRating,
round(avg(averageRating) over(order by numVotes desc rows between current row and 2 following),2) as ranking
from (select * from titles_ratings) as brab inner join titles_basics tb on brab.tconst = tb.tconst
order by numVotes desc limit 10