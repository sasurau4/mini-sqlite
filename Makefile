db: db.c
	gcc db.c -o db

run: db
	./db mydb.db

clean:
	rm -f db *.db

test: db
	bundle exec rspec

.PHONEY: clean