--Lien doc postgresql erreurs: https://www.postgresql.org/docs/current/errcodes-appendix.html

--Créer un docker "postgresProjet" en se plaçant d'abord dans le dossier local src: docker run --name postgresProjet -d -p 55433:5432 -e POSTGRES_PASSWORD=toto --mount type=bind,src=$(pwd),target=/sql postgres:15-alpine
--Se connecter au docker: docker exec -it postgresProjet bash
--Se placer dans le dossier sql: cd sql
--Se connecter à la base de données: psql -U postgres
--Lancer le(s) script(s): \i [nom du fichier].sql

DROP TABLE IF EXISTS "transport_type", "zone", "station", "line", "station_to_line", "person", "employee", "contract", "offer", "subscription", "bill", "journey", "service", "offers_history" CASCADE;

CREATE TABLE "transport_type" (
  "code" VARCHAR(3) UNIQUE PRIMARY KEY,
  "name" VARCHAR(32) UNIQUE,
  "capacity" int NOT NULL CHECK (capacity > 0),
  "avg_interval" int NOT NULL CHECK (capacity > 0)
);

CREATE TABLE "zone" (
  "id" SERIAL PRIMARY KEY,
  "name" VARCHAR(32),
  "price" FLOAT
);

CREATE TABLE "station" (
  "id" int PRIMARY KEY,
  "name" VARCHAR(64),
  "town" VARCHAR(32),
  "zone" int,
  "type" Varchar(3)
);

CREATE TABLE "line" (
  "code" VARCHAR(3) PRIMARY KEY,
  "transport_id" VARCHAR(3)
);

CREATE TABLE "station_to_line" (
  "line" varchar(3),
  "station" int,
  "pos" int
);

CREATE TABLE "person" (
  "id" serial UNIQUE PRIMARY KEY,
  "firstname" varchar(32),
  "lastname" varchar(32),
  "email" varchar(128) UNIQUE,
  "phone" char(10),
  "address" text,
  "town" varchar(32),
  "zipcode" char(5)
);

CREATE TABLE "employee" (
  "login" varchar(20) UNIQUE,
  "email" VARCHAR(128) UNIQUE
);

CREATE TABLE "service" (
  "name" varchar(32) PRIMARY KEY,
  "discount" int
);

CREATE TABLE "contract" (
  "login" varchar(20),
  "email" Varchar(128),
  "date_beginning" date,
  "end_contract" date,
  "service" varchar(32)
);

CREATE TABLE "journey" (
  "email" int,
  "time_start" date,
  "time_end" date,
  "station_start" int,
  "station_end" int
);

CREATE TABLE "offer" (
  "code" varchar(5) PRIMARY KEY, 
  "name" varchar(32),
  "price" decimal(10,2),
  "nb_month" int,
  "zone_from" int,
  "zone_to" int
);

CREATE TABLE "subscription" (
  "num" int UNIQUE PRIMARY KEY,
  "email" varchar(128),
  "code" varchar(5),
  "date_sub" date,
  "status" varchar(20) DEFAULT 'Incomplete'
);

CREATE TABLE "bill" (
  "id" serial PRIMARY KEY,
  "email" VARCHAR(128),
  "year" int,
  "month" int,
  "montant_total" decimal(10,2),
  "status" varchar(20)
);

CREATE TABLE "offers_history" (
  "offer_code" VARCHAR(5) NOT NULL,
  "modified_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  "old_price" DECIMAL(10,2),
  "new_price" DECIMAL(10,2)
);

-- ajout des clés étrangères
ALTER TABLE "station" ADD FOREIGN KEY ("zone") REFERENCES "zone" ("id");

ALTER TABLE "station" ADD FOREIGN KEY ("type") REFERENCES "transport_type" ("code");

ALTER TABLE "line" ADD FOREIGN KEY ("transport_id") REFERENCES "transport_type" ("code");

ALTER TABLE "station_to_line" ADD FOREIGN KEY ("line") REFERENCES "line" ("code");

ALTER TABLE "station_to_line" ADD FOREIGN KEY ("station") REFERENCES "station" ("id");

ALTER TABLE "employee" ADD FOREIGN KEY ("email") REFERENCES "person" ("email") ON UPDATE CASCADE;

ALTER TABLE "contract" ADD FOREIGN KEY ("login") REFERENCES "employee" ("login"); 

ALTER TABLE "contract" ADD FOREIGN KEY ("email") REFERENCES "employee" ("email") ON UPDATE CASCADE; 

ALTER TABLE "contract" ADD FOREIGN KEY ("service") REFERENCES "service" ("name");

ALTER TABLE "journey" ADD FOREIGN KEY ("email") REFERENCES "person" ("id");

ALTER TABLE "journey" ADD FOREIGN KEY ("station_start") REFERENCES "station" ("id");

ALTER TABLE "journey" ADD FOREIGN KEY ("station_end") REFERENCES "station" ("id");

ALTER TABLE "offer" ADD FOREIGN KEY ("zone_from") REFERENCES "zone" ("id");

ALTER TABLE "offer" ADD FOREIGN KEY ("zone_to") REFERENCES "zone" ("id");

ALTER TABLE "subscription" ADD FOREIGN KEY ("email") REFERENCES "person" ("email") ON UPDATE CASCADE; 

ALTER TABLE "subscription" ADD FOREIGN KEY ("code") REFERENCES "offer" ("code");

ALTER TABLE "bill" ADD FOREIGN KEY ("email") REFERENCES "person" ("email"); 