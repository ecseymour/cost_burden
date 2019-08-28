from pysqlite2 import dbapi2 as sql
import csv

inFile = "/home/eric/Documents/franklin/cost_burden/generated_data/rent_burden_data.csv"
with open(inFile, 'rb') as f:
	reader = csv.reader(f)
	header = reader.next()
	first = reader.next()

for i, x in enumerate(zip(header, first)):
	print i, x

dataDict = {}
with open(inFile, 'rb') as f:
	reader = csv.reader(f)
	header = reader.next()
	for row in reader:
		nhgisjoin = row[0]
		name = row[1]
		gjoin1980 = row[2]
		gjoin2012 = row[6]
		state = row[7]
		dataDict[nhgisjoin] = { 
			'Y1980' : {gjoin1980 : -99},
			'Y2012' : {gjoin2012 : -99},
			'name' : name,
			'change': -99,
			'state': state
			}
	
# for k, v in dataDict.iteritems():
# 	print "+" * 50
# 	for k1, v1 in v['Y1980'].iteritems():
# 		print k1, v1

db = "/home/eric/Documents/franklin/cost_burden/generated_data/place_geos.sqlite"
con = sql.connect(db)
con.enable_load_extension(True)
con.execute("SELECT load_extension('mod_spatialite');")
cur = con.cursor()

for k, v in dataDict.iteritems():
	for k1, v1 in v['Y1980'].iteritems():
		cur.execute('''
			SELECT ST_Area(GEOMETRY)
			FROM US_place_1980
			WHERE GISJOIN = ?;
			''', ([k1]))
		result = cur.fetchone()
		if result is not None:
			dataDict[k]['Y1980'][k1] = result[0]
		else:
			pass

for k, v in dataDict.iteritems():
	for k1, v1 in v['Y2012'].iteritems():
		cur.execute('''
			SELECT ST_Area(GEOMETRY)
			FROM US_place_2017
			WHERE GISJOIN = ?;
			''', ([k1]))
		result = cur.fetchone()
		if result is not None:
			dataDict[k]['Y2012'][k1] = result[0]
		else:
			pass

for k, v in dataDict.iteritems():
	if v['Y1980'].items()[0][1] != -99 and v['Y2012'].items()[0][1] != -99:
		dataDict[k]['change'] = (v['Y2012'].items()[0][1] - v['Y1980'].items()[0][1]) / v['Y1980'].items()[0][1] * 100
		dataDict[k]['change'] = round(dataDict[k]['change'], 2)
	else:
		dataDict[k]['change'] = 'missing'


outF = "/home/eric/Documents/franklin/cost_burden/generated_data/land_area_change.csv"
with open(outF, 'wb') as f:
	writer = csv.writer(f)
	writer.writerow(['NHGISJOIN', 'name', 'state', 'gjoin1980', 'gjoin2012', 'change'])
	for k, v in dataDict.iteritems():
		row = [k, v['name'], v['state'], v['Y1980'].items()[0][0], v['Y2012'].items()[0][0], v['change']]
		writer.writerow(row)


con.close()