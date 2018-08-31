import csv
import sqlite3 as sql
import re

# connect to db
db = "/home/eric/Documents/franklin/cost_burden/generated_data/cost_burden.sqlite"
con = sql.connect(db)
con.text_factory=str
cur = con.cursor()
#################################################################
geographies = ['county', 'place']
# geographies = ['county']

break_downs = ['ds225', 'ds226']

# make table schema

for g in geographies:

	for b in break_downs:

		print "+" * 60
		print "table", g, b

		field_only = []
		schema = []
		# add context fields to schema
		codebook = "/home/eric/Documents/franklin/cost_burden/source_data/nhgis0052_csv/nhgis0052_{}_20165_2016_{}_codebook.txt".format(b, g)
		with open(codebook, 'rb') as f:
			for line in f:
				if "Context Fields" in line:
					break
			for line in f:
				if "Data Type (E)" in line:
					break
				field_name = line.strip().split(":")[0]
				field = (field_name, 'TEXT')
				field = ' '.join(field)
				if field_name != '':
					field_only.append(field_name)
					schema.append(field)

		# add table data to schema
		with open(codebook, 'rb') as f:
			for line in f:
				if b=='ds225':
					if re.match(r'.*\bAF\d\w{2}\d{3}', line):
						field_name = line.strip().split(":")[0]
						field = (field_name, 'INT')
						field = ' '.join(field)
						if field_name != '':
							field_only.append(field_name)
							schema.append(field)
					elif re.match(r'.*\bNAME_\w', line):
						field_name = line.strip().split(":")[0]
						field = (field_name, 'TEXT')
						field = ' '.join(field)
						if field_name != '':
							field_only.append(field_name)
							schema.append(field)
				else:
					if re.match(r'.*\bAGQ\d\w\d{3}', line):
						field_name = line.strip().split(":")[0]
						field = (field_name, 'INT')
						field = ' '.join(field)
						if field_name != '':
							field_only.append(field_name)
							schema.append(field)
					elif re.match(r'.*\bNAME_\w', line):
						field_name = line.strip().split(":")[0]
						field = (field_name, 'TEXT')
						field = ' '.join(field)
						if field_name != '':
							field_only.append(field_name)
							schema.append(field)					

		# for x in schema:
		# 	print x

		tablename = 'nhgis_20165_{}_{}'.format(g, b)
		cur.execute("DROP TABLE IF EXISTS {};".format(tablename))
		cur.execute("CREATE TABLE IF NOT EXISTS {} ({});".format(tablename,  ', '.join(map(str, schema))))

		# create insert template
		cur.execute("SELECT * FROM {};".format(tablename))
		fields = list([cn[0] for cn in cur.description])
		qmarks = ["?"] * len(fields)
		insert_tmpl = "INSERT INTO {} ({}) VALUES ({});".format(tablename, ', '.join(map(str, fields)),', '.join(map(str, qmarks)))
		print insert_tmpl
		#################################################################
		# insert data into newly created table
		datafile = "/home/eric/Documents/franklin/cost_burden/source_data/nhgis0052_csv/nhgis0052_{}_20165_2016_{}.csv".format(b, g)
		with open(datafile, 'rb') as f:
			reader = csv.reader(f)
			header = reader.next()
			for row in reader:
				cur.execute(insert_tmpl,row)

		con.commit()
		print "{} changes made".format(con.total_changes)

		if g=='county':
			cur.execute("CREATE INDEX idx_{}_{}_state_county ON {}('STATEA', 'COUNTYA');".format(b,g,tablename))
			cur.execute("CREATE INDEX idx_{}_{}_gisjoin ON {}('GISJOIN');".format(b,g,tablename))


con.close()