--Exercice 1 : Utilisation des CTE et sous-requêtes (6 points)
--Trouvez les utilisateurs qui ont commenté leurs propres posts. Affichez les colonnes :

--username : le nom d'utilisateur
--post_id : l'ID du post commenté
--comment_id : l'ID du commentaire

with post_createur as (
	select u.user_id , p.post_id 
	from posts p
	join users u on u.user_id = p.user_id
)
select u.username, pc.post_id, c.comment_id from users u
join post_createur pc on pc.user_id = u.user_id 
join comments c on c.post_id = pc.post_id and pc.user_id = c.user_id;

select u.username, p.post_id, c.comment_id, u.user_id
from users u
join posts p on p.user_id = u.user_id
join comments c on c.user_id = u.user_id and p.post_id = c.post_id;

/* résultat
username   post_id  comment_id
rebecca36	85	50
choirobert	34	75
ocharles	79	76
ocharles	87	118
williamsonhenry	68	171
*/




--Exercice 2 : Fonctions Fenêtres (5 points)
--Trouvez les trois utilisateurs les plus actifs en termes de nombre total de likes reçus sur leurs posts. Affichez :

--username : le nom d'utilisateur
--total_likes : le nombre total de likes reçus
--rank : le rang de l'utilisateur basé sur le nombre de likes.

with nb_like as (
	select count(l.like_id) as nb_Like, p.user_id 
	from likes l 
	join posts p on l.post_id = p.post_id
	group by p.post_id, p.user_id
)
select username, nb_like as total_likes,
rank() over (order by nb_like desc)
from users u 
join nb_like nl on u.user_id = nl.user_id
limit 3;

/* résultat
 username  total_likes rank 
haleheidi	6	1
susanblack	5	2
yumark		4	3
 */

--Exercice 3 : GROUPING SETS, ROLLUP, CUBE (5 points)
--Calculez le nombre total de posts et de commentaires créés par chaque utilisateur. Affichez :

--user_id : l'ID de l'utilisateur (peut être NULL pour les totaux globaux)
--content_type : 'Post', 'Comment' ou NULL pour les totaux globaux
--total_count : le nombre total de contenus créés pour ce groupe.

with nb_commentaire as (
    select count(*) as nb_commentaire, c.user_id 
    from comments c 
    group by c.user_id 
),
nb_post as (
    select count(*) as nb_post, p.user_id 
    from posts p 
    group by p.user_id
)
select 
    user_id, 
    content_type, 
    sum(total_count) as total_count
from (
    select 
        np.user_id, 
        'Post' as content_type, 
        np.nb_post as total_count
    from nb_post np
    union all
    select 
        nc.user_id, 
        'Comment' as content_type, 
        nc.nb_commentaire as total_count
    from nb_commentaire nc
    union all
    select 
        null as user_id, 
        'Post' as content_type, 
        sum(np.nb_post) as total_count
    from nb_post np
    union all
    select 
        null as user_id, 
        'Comment' as content_type, 
        sum(nc.nb_commentaire) as total_count
    from nb_commentaire nc
    union all
    select 
        null as user_id, 
        null as content_type, 
        (select count(*) from posts) + (select count(*) from comments) as total_count
) as combine
group by grouping sets (
    (user_id, content_type), 
    ()
)
order by  user_id, content_type;


/* fin des résultats trop long
 user_id  content_type  total_count
49	Comment	3
49	Post	2
50	Comment	3
50	Post	2
Comment	200
Post	100
NULL	300
NULL	900
 */

--Exercice 4 : Triggers ou Procédures Stockées (4 points)
--Créez un trigger qui, à chaque fois qu'un utilisateur est tagué dans un post, insère une notification dans une table notifications. La table notifications doit contenir les colonnes suivantes :

--notification_id : clé primaire 
--user_id : l'ID de l'utilisateur qui reçoit la notification 
--message : le contenu de la notification 
--created_at : la date et l'heure de la notification

-- création de la nouvelle table
create table notifications (
	notification_id SERIAL PRIMARY KEY,
	user_id INTEGER NOT NULL references users(user_id),
	message varchar(255) not null,
	created_at TIMESTAMP DEFAULT NOW()
)

-- création de fonction déclencher par le trigger
CREATE OR REPLACE FUNCTION new_notification()
RETURNS TRIGGER AS $$
BEGIN
	if new.tagged_user_id > 0 then
		INSERT INTO notifications (user_id, message) VALUES (new.tagged_user_id, 'Nouvelle notificion');
	end if;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- création et mise place du trigger
CREATE OR REPLACE TRIGGER new_notif
AFTER INSERT ON user_tags
FOR EACH ROW
EXECUTE FUNCTION new_notification();


-- fonction de test
select * from user_tags ut where ut.tag_id =99; -- vérification si le tag existe
delete from user_tags where tag_id = 99; -- suppréssion du tag
insert into user_tags (tag_id ,post_id,tagged_user_id,tagged_by_user_id) values (99,1,1,1); -- ajout du tag

select * from notifications; -- vérification de la nouvelle notification
delete from notifications; -- suppréssion de toutes notif

-- id	User_id	message	created_at
-- 5	1	Nouvelle notificion	2024-11-26 16:06:55.565

--Exercice Bonus : Optimisation avec Index et EXPLAIN
--Analysez et optimisez cette requête lente en ajoutant un index ou en optimisant cette requête. Montrez les plans d'exécution avant et après optimisation.

SELECT p.post_id, p.content, u.username, p.created_at
FROM posts p
JOIN users u ON p.user_id = u.user_id
WHERE p.created_at >= NOW() - INTERVAL '7 days'
ORDER BY p.created_at DESC;

-- ajouter un indexe sur creatd_at car c'est utiliser pour une recherche

-- si la selection n'est pas correct pour son usage. 
-- Par exemple pour une page internet, esque l'on veux afficher
-- tous les poste en base de donnée, ou si l'on prend en compte 
-- que l'on vas ajouter les poste en bd au moment de sa création,
--on a pas besoin de trier 

SELECT p.post_id, p.content, u.username, p.created_at
FROM posts p
JOIN users u ON p.user_id = u.user_id
WHERE p.created_at >= NOW() - INTERVAL '7 days'
limit  50;

CREATE UNIQUE INDEX created_at_idx ON posts(created_at); 
-- Code qui ne fonctionne pas, car on a créer toutes les donnée en même temps, 
-- mais normalement cela ne peux pas arrivé ou trés rare car on utilise les micros secondes.


/* plan d'exécution après optimisation
Sort  (cost=20.37..20.62 rows=100 width=293) (actual time=1.426..1.449 rows=100 loops=1)
   Sort Key: p.created_at DESC
   Sort Method: quicksort  Memory: 47kB
   ->  Hash Join  (cost=12.03..17.05 rows=100 width=293) (actual time=0.466..1.040 rows=100 loops=1)
         Hash Cond: (p.user_id = u.user_id)
         ->  Seq Scan on posts p  (cost=0.00..4.75 rows=100 width=179) (actual time=0.127..0.383 rows=100 loops=1)
               Filter: (created_at >= (now() - '7 days'::interval))
         ->  Hash  (cost=10.90..10.90 rows=90 width=122) (actual time=0.259..0.260 rows=50 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 11kB
               ->  Seq Scan on users u  (cost=0.00..10.90 rows=90 width=122) (actual time=0.075..0.101 rows=50 loops=1)
 Planning Time: 0.988 ms
 Execution Time: 1.778 ms
(12 rows)
*/

/* plan d'exécution après optimisation
-
 Limit  (cost=6.00..12.34 rows=50 width=293) (actual time=0.355..0.407 rows=50 loops=1)
   ->  Hash Join  (cost=6.00..18.69 rows=100 width=293) (actual time=0.351..0.392 rows=50 loops=1)
         Hash Cond: (u.user_id = p.user_id)
         ->  Seq Scan on users u  (cost=0.00..10.90 rows=90 width=122) (actual time=0.034..0.039 rows=26 loops=1)
         ->  Hash  (cost=4.75..4.75 rows=100 width=179) (actual time=0.222..0.223 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 30kB
               ->  Seq Scan on posts p  (cost=0.00..4.75 rows=100 width=179) (actual time=0.024..0.152 rows=100 loops=1)
                     Filter: (created_at >= (now() - '7 days'::interval))
 Planning Time: 0.425 ms
 Execution Time: 0.480 ms
(10 rows)
*/