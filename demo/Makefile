
DEMO_DUMP_SQL = demo.sql
DEMO_DUMP_SQL_GZ = $(DEMO_DUMP_SQL).gz

.PHONY: $(DEMO_DUMP_SQL)
$(DEMO_DUMP_SQL):
	pg_dump -d vasco -n vasco_demo --no-owner > $@

$(DEMO_DUMP_SQL_GZ): $(DEMO_DUMP_SQL)
	gzip --best --keep --stdout $< > $@

METABASE_JAR_FILE = metabase.jar

$(METABASE_JAR_FILE):
	wget https://downloads.metabase.com/v0.47.0/metabase.jar -O $@

MB_DB_FILE = ./metabase.h2.db
run-metabase: $(METABASE_JAR_FILE)
	# user: florents@tselai.com pass: v@sc01
	MB_DB_TYPE=h2 MB_DB_FILE=$(MB_DB_FILE); java -jar $(METABASE_JAR_FILE)

all: $(DEMO_DUMP_SQL) $(DEMO_DUMP_SQL_GZ)

clean-metabase:
	rm $(MB_DB_FILE)

clean:
	rm $(DEMO_DUMP_SQL) $(DEMO_DUMP_SQL_GZ) $(METABASE_JAR_FILE)