'''
file imports all tables needed for cost-burden project
'''

import sqlite3 as sql
import csv
import re
import glob

# connect to db
db = "/home/eric/Documents/franklin/cost_burden/generated_data/cost_burden.sqlite"
con = sql.connect(db)
con.text_factory=str
cur = con.cursor()


path = "/home/eric/Documents/franklin/cost_burden/source_data/nhgis0105_csv/*.csv"
for fname in glob.glob(path):
	print "+" * 60
	print fname
	codebook = fname.replace('.csv', '_codebook.txt')
	print codebook
	tablename = fname.split('/')[-1].split('.')[0][10:]
	print tablename

	field_only = []
	schema = []
	# add context fields to schema
	with open(codebook, 'rb') as f:
		for line in f:
			if "Context Fields" in line:
				break
		for line in f:
			if "---" in line:
				break
			if line.startswith(' '*8) and tablename != 'ds94_1970_place':
				# print line				
				field_name = line.strip().split(":")[0]
				if any(i.isdigit() for i in field_name):
					field = (field_name, 'INT')
				else:
					field = (field_name, 'TEXT')
				field = ' '.join(field)
				if field_name != '':
					field_only.append(field_name)
					schema.append(field)

			if line.startswith(' '*4) and tablename == 'ds94_1970_place':
				# print line				
				field_name = line.strip().split(":")[0]
				if any(i.isdigit() for i in field_name):
					field = (field_name, 'INT')
				else:
					field = (field_name, 'TEXT')
				field = ' '.join(field)
				if field_name != '':
					field_only.append(field_name)
					schema.append(field)


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
	with open(fname, 'rb') as f:
		reader = csv.reader(f)
		header = reader.next()
		for row in reader:
			cur.execute(insert_tmpl,row)

	con.commit()
	if tablename == 'ts_nominal_place':
		cur.execute("CREATE INDEX idx_{}_gisjoin ON {}('nhgiscode');".format(tablename, tablename))
		years = ['1970', '1980', '1990', '2000', '2012']
		for y in years:
			try:
				cur.execute("CREATE INDEX idx_{}_GJOIN{} ON {}('GJOIN{}');".format(tablename, y, tablename, y))
			except:
				pass
	else:
		cur.execute("CREATE INDEX idx_{}_gisjoin ON {}('GISJOIN');".format(tablename, tablename))

	cur.execute("CREATE INDEX idx_{}_placea ON {}('PLACEA');".format(tablename, tablename))
	con.commit()

con.close()