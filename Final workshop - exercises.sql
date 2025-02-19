
#Tento SQL dotaz analyzuje historii poskytnutých půjček (loan) a vytváří
# souhrnnou statistiku podle roku, čtvrtletí a měsíce.

select                     #History of granted loans

    year(date)as rok,
    quarter(date)as kvartal,
    month(date)as mesic,
    sum(amount)as celkova_suma_kreditu,
    count(loan_id)as pocet_pucek,
    round(AVG(amount),1) as priemka_na_pucku
from loan l
group by date, date, date;

######


# Tento SQL dotaz analyzuje stav půjček podle jejich statusu a počítá jejich počet

SELECT                     #     Loan status
    status,
    count(loan_id)as pocet_pucek,
    CASE
        WHEN status IN('A','C') THEN 'pohaseny_kredit'
        WHEN status IN ('B', 'D') THEN 'nepohaseny_kredit'
    else 'Neznamy'
end as stav_půjčky
FROM loan l
GROUP BY status;

########


# Tento SQL dotaz provádí analýzu účtů, které mají půjčky se statusem 'A' nebo 'C'

select                             #     Analysis of accounts
    account_id as id_účtu,
      count(loan_id)as pocet_pucek,
      sum(amount)as celkova_suma_kreditu,
      round(AVG(amount),1)as priemka_na_pucku
from loan l
where status IN ('A','C')
group by account_id
order by pocet_pucek desc,
         celkova_suma_kreditu desc,
         priemka_na_pucku desc;

#######


# Tento dotaz analyzuje celkovou sumu poskytnutých půjček podle pohlaví klienta

                                     #  Fully paid loans
select
     c.gender,
    SUM(l.amount) AS celkova_suma_kreditu
from client c
inner join district on c.district_id = district.district_id
join account on district.district_id = account.district_id
join loan l on account.account_id = l.account_id
WHERE l.status IN ('A', 'C')
group by c.gender;

 # Vytvoření CTE
WITH celkova_suma_kreditu_cte AS(
select
     c.gender,
    SUM(l.amount) AS celkova_suma_kreditu
from client c
inner join district on c.district_id = district.district_id
join account on district.district_id = account.district_id
join loan l on account.account_id = l.account_id
WHERE l.status IN ('A', 'C')
group by c.gender
)
SELECT * FROM celkova_suma_kreditu_cte;

#  Vytvoření dočasné tabulky
DROP TEMPORARY TABLE IF EXISTS result;
CREATE TEMPORARY TABLE result AS
select
     c.gender,
    SUM(l.amount) AS celkova_suma_kreditu
from client c
inner join district on c.district_id = district.district_id
join account on district.district_id = account.district_id
join loan l on account.account_id = l.account_id
join disp on account.account_id = disp.account_id
WHERE l.status IN ('A', 'C')
and type !='DISPONENT'
group by c.gender;

#Výpočet rozdílu mezi
with cte as(
    select
        sum(amount) as total_amount
    from loan
    WHERE status IN ('A', 'C')
)
SELECT
    (SELECT SUM(celkova_suma_kreditu) FROM result) -
    (SELECT total_amount FROM cte) AS rozdil;

######


#  Tento dotaz analyzuje pohlaví klientů, počet jejich splacených
#  půjček, celkovou sumu půjček a jejich průměrný věk.

                                #   Client analysis - part 1
WITH client_age_cte AS (
    SELECT
        client_id,
        gender,
        (2024 - EXTRACT(YEAR FROM birth_date)) AS vek
    FROM client)
select
    c.gender as pohlavy,
    count(amount)pocet_pucek,
    sum(amount)as suma,
    round(avg(ca.vek),1)as prumerny_vek
from client c
inner join district on c.district_id = district.district_id
inner join account a ON district.district_id = a.district_id
inner join loan l on a.account_id = l.account_id
inner join client_age_cte ca on c.client_id = ca.client_id
WHERE l.status IN ('A', 'C')
GROUP BY c.gender;


                                   #   Druhá možnost
WITH client_age_cte AS (
    SELECT
        gender,
        ROUND(AVG(TIMESTAMPDIFF(YEAR, birth_date, '2024-01-01'))) AS vek
FROM client
GROUP BY gender)
select
    c.gender as pohlavy,
    count(*)as pocet_pucek,
    sum(amount)as suma,
    round(avg(ca.vek),1)as prumerny_vek
from client c
inner join district on c.district_id = district.district_id
inner join account a ON district.district_id = a.district_id
inner join loan l on a.account_id = l.account_id
inner join client_age_cte ca ON c.gender = ca.gender
WHERE l.status IN ('A', 'C')
group by c.gender;

######

#  Tento dotaz analyzuje půjčky a klienty v jednotlivých okresech

                     #           Client analysis - part 2
select
       a2 as okres,
       count(distinct c.client_id) as pocet_klientu,
       count(distinct l.account_id) as pocet_pujcek,
       sum(amount)as celkova_splacena_castka
from district d
join client c on d.district_id = c.district_id
join disp on c.client_id = disp.client_id
join account a on d.district_id = a.district_id
join loan l on a.account_id = l.account_id
where type ='OWNER'
and l.status IN ('A', 'C')
group by a2
order by pocet_klientu desc;

##########


     #   Tento dotaz analyzuje splacené půjčky podle okresů

                     #           Client analysis - part 3
select
       a2 as okres,
       count(distinct c.client_id) as pocet_klientu,
       count(distinct l.account_id) as pocet_pujcek,
       sum(amount)as celkova_splacena_castka,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER(), 2) as amount_share
from district d
join client c on d.district_id = c.district_id
join disp on c.client_id = disp.client_id
join account a on d.district_id = a.district_id
join loan l on a.account_id = l.account_id
where type ='OWNER'
and l.status IN ('A', 'C')
group by a2
order by pocet_klientu desc;

######


#  Tento dotaz analyzuje klienty narozené po roce 1990, kteří:
# Mají více než 5 půjček.
#  Mají zůstatek na účtu vyšší než 1000.

                                  # Selection - part 1
select
    c.client_id,
    COUNT( l.loan_id) AS pocet_pujcek
from loan l
join account on l.account_id = account.account_id
join disp on account.account_id = disp.account_id
join client c on disp.client_id = c.client_id
JOIN trans t on account.account_id = t.account_id
where c.birth_date>'1990-01-01'
and t.balance > 1000
group by c.client_id
having COUNT( l.loan_id)>5;
# V daném případě musí dojít ke změně ve dvou podmínkách.
########




                              #         Selection - part 2

         #  Nejsou žádní lidé narození po roce 1990
SELECT COUNT(*) AS after_1990
FROM client
WHERE birth_date > '1990-01-01';


  #  Nejsou žádní klienti, kteří mají více než 5 půjček.
SELECT COUNT(*)
FROM (
    SELECT c.client_id
    FROM loan l
    JOIN account a ON l.account_id = a.account_id
    JOIN disp d ON a.account_id = d.account_id
    JOIN client c ON d.client_id = c.client_id
    GROUP BY c.client_id
    HAVING COUNT(l.loan_id) > 5
) subquery;


####

# informace o kartách s datem expirace mezi 1. lednem 2000 a 29. prosincem 2005,
# včetně klientů a jejich adres

                      #    Expiring cards


DROP PROCEDURE IF EXISTS update_cards_at_expiration;

DELIMITER $$

CREATE PROCEDURE update_cards_at_expiration()
BEGIN
    #TRUNCATE TABLE cards_at_expiration;

    INSERT INTO cards_at_expiration (client_id, card_id, expiration_date, client_address)
    SELECT
        cl.client_id,
        cr.card_id,
        DATE_ADD(cr.issued, INTERVAL 3 YEAR) AS expiration_date,
        dist.A3 AS client_address
    FROM card cr
    JOIN disp d ON cr.disp_id = d.disp_id
    JOIN client cl ON d.client_id = cl.client_id
    JOIN district dist ON cl.district_id = dist.district_id
    WHERE DATE_ADD(cr.issued, INTERVAL 3 YEAR)
          BETWEEN '2000-01-01' AND '2005-12-29';
END $$

DELIMITER ;

CALL update_cards_at_expiration();
SELECT * FROM cards_at_expiration;
