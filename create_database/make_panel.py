'''
pull data for panel:
for 1980, 1990, 2000, 2008-2012, 2013-2017:
	pull median gross rent
	median renter household income
	percent renter households paying 30% or more of income toward gross rent
	also need pop change

how to handle places that don't exist across all periods?
would counties be a preferable unit for this reason?
or collect places that exist across all periods, then collect data for those places?
'''

import sqlite3 as sql
import pandas as pd
from collections import OrderedDict

# connect to db
db = "/home/eric/Documents/franklin/cost_burden/generated_data/cost_burden.sqlite"
con = sql.connect(db)
con.text_factory=str
cur = con.cursor()

#############################################################
# pull cities that exist across time from nhgis nominal time-series table
code_dict = OrderedDict()
cur.execute('''
	SELECT NHGISCODE, PLACE, GJOIN1980, GJOIN1990, GJOIN2000, GJOIN2010, GJOIN2012,
	STATE, AV0AA1970
	FROM nhgis0087_ts_nominal_place
	WHERE AV0AA1970 <> '' 
	AND AV0AA1980 <> ''
	AND AV0AA1990 <> ''
	AND AV0AA2000 <> ''
	AND AV0AA2010 <> ''
	AND AV0AA125 <> ''
	AND AV0AA1970 > 10000
	AND B37AA1970 > 1000
	;
	''')
results = cur.fetchall()
for row in results:
	code_dict[row[0]] = OrderedDict()
	code_dict[row[0]]['PLACE'] = row[1]
	code_dict[row[0]]['GJOIN1980'] = row[2]
	code_dict[row[0]]['GJOIN1990'] = row[3]
	code_dict[row[0]]['GJOIN2000'] = row[4]
	code_dict[row[0]]['GJOIN2010'] = row[5]
	code_dict[row[0]]['GJOIN2012'] = row[6]
	code_dict[row[0]]['STATE'] = row[7]
	code_dict[row[0]]['pop70'] = row[8]

print len(code_dict)
#############################################################
# 1980
for k, v in code_dict.iteritems():
	cur.execute('''
	SELECT A.GISJOIN,
	A.C9H001 AS pop,
	B.DFK001* 3.21 AS rent,
	C.DPO002 * 3.21 AS income,
	(D.DKY006 + D.DKY007 + D.DKY008 + D.DKY009 + D.DKY010) * 1.0 /
	(D.DKY001 + D.DKY002 + D.DKY003 + D.DKY004 + D.DKY005 + D.DKY006 + D.DKY007 + D.DKY008 + D.DKY009 + D.DKY010) * 100 AS burden,
	E.A43AB1980 * 1.0 / (E.A43AB1980 + E.A43AA1980) * 100 AS vacrate,
	E.B37AB1980 AS renters,
	E.B37AB1980 * 1.0 / (E.B37AB1980 + E.B37AA1980) * 100 AS tenure,
	E.B69AC1980 * 1.0 / (E.B69AC1980 + E.B69AB1980 + E.B69AA1980) * 100 AS BArate,
	E.AX7AA1980 * 1.0 / (E.AX7AB1980 + E.AX7AA1980) * 100 AS povrate,
	F.C8J001 AS medval,
	(B.DEQ007 + B.DEQ006) * 1.0 / (B.DEQ007 + B.DEQ006 + B.DEQ004 + B.DEQ003 + B.DEQ002 + B.DEQ001) * 100 AS bltpre1950
	FROM nhgis0087_ds105_1980_place AS A
	JOIN nhgis0087_ds107_1980_place AS B ON A.GISJOIN = B.GISJOIN
	JOIN nhgis0087_ds109_1980_place AS C ON A.GISJOIN = C.GISJOIN 
	JOIN nhgis0087_ds108_1980_place AS D ON A.GISJOIN = D.GISJOIN
	JOIN nhgis0087_ts_nominal_place AS E ON A.GISJOIN = E.GJOIN1980
	JOIN nhgis0087_ds104_1980_place AS F ON A.GISJOIN = F.GISJOIN
	WHERE A.GISJOIN = ?;
	''', ([v['GJOIN1980']]))
	results = cur.fetchall()
	for row in results:
		code_dict[k]['pop80'] = row[1]
		code_dict[k]['rent80'] = row[2]
		code_dict[k]['inc80'] = row[3]
		code_dict[k]['burd80'] = row[4]	
		code_dict[k]['vac80'] = row[5]	
		code_dict[k]['renterHH80'] = row[6]	
		code_dict[k]['renterPct80'] = row[7]	
		code_dict[k]['BArate80'] = row[8]
		code_dict[k]['povrate80'] = row[9]
		code_dict[k]['medHmVal80'] = row[10]
		code_dict[k]['bltPre195080'] = row[11]
#############################################################
# 1990
for k, v in code_dict.iteritems():
	cur.execute('''
	SELECT A.GISJOIN,
	A.ET1001 AS pop,
	B.EYU001 * 1.95 AS rent,
	(B.EY2004 + B.EY2005 + B.EY2010 + B.EY2011 + B.EY2016 + B.EY2017 + B.EY2022 + B.EY2023 + B.EY2028 + B.EY2029) * 1.0 /
	(B.EY2004 + B.EY2005 + B.EY2010 + B.EY2011 + B.EY2016 + B.EY2017 + B.EY2022 + B.EY2023 + B.EY2028 + B.EY2029 + 
	B.EY2001 + B.EY2002 + B.EY2003 + B.EY2007 + B.EY2008 + B.EY2009 + B.EY2013 + B.EY2014 + B.EY2015 + B.EY2019 + 
	B.EY2020 + B.EY2021 + B.EY2025 + B.EY2026 + B.EY2027) * 100 AS burden,
	E.A43AB1990 * 1.0 / (E.A43AB1990 + E.A43AA1990) * 100 AS vacrate,
	E.B37AB1990 AS renters,
	E.B37AB1990 * 1.0 / (E.B37AB1990 + E.B37AA1990) * 100 AS tenure,
	E.B69AC1990 * 1.0 / (E.B69AC1990 + E.B69AB1990 + E.B69AA1990) * 100 AS BArate,
	E.AX7AA1990 * 1.0 / (E.AX7AB1990 + E.AX7AA1990) * 100 AS povrate,
	A.EST001 AS medval,
	(B.EX7008 + B.EX7007) * 1.0 / (B.EX7008 + B.EX7007 + B.EX7006 + B.EX7005 + B.EX7004 + B.EX7003 + B.EX7002 + B.EX7001) * 100 AS bltpre1950
	FROM nhgis0087_ds120_1990_place AS A
	JOIN nhgis0087_ds123_1990_place AS B ON A.GISJOIN = B.GISJOIN
	JOIN nhgis0087_ts_nominal_place AS E ON A.GISJOIN = E.GJOIN1990
	WHERE A.GISJOIN = ?;
	''', ([v['GJOIN1990']]))
	results = cur.fetchall()
	for row in results:
		code_dict[k]['pop90'] = row[1]
		code_dict[k]['rent90'] = row[2]
		code_dict[k]['burd90'] = row[3]	
		code_dict[k]['vac90'] = row[4]	
		code_dict[k]['renterHH90'] = row[5]	
		code_dict[k]['renterPct90'] = row[6]
		code_dict[k]['BArate90'] = row[7]
		code_dict[k]['povrate90'] = row[8]
		code_dict[k]['medHmVal90'] = row[9]
		code_dict[k]['bltPre195090'] = row[10]
#############################################################
# 2000
for k, v in code_dict.iteritems():
	cur.execute('''
	SELECT A.GISJOIN,
	A.GHC001 AS pop,
	A.GBO001 * 1.46 AS rent,
	A.GED002 * 1.46 AS income,
	(A.GBW006 + A.GBW007 + A.GBW008 + A.GBW009) * 1.0 / 
	(A.GBW001 + A.GBW002 + A.GBW003 + A.GBW004 + A.GBW005 + A.GBW006 + A.GBW007 + A.GBW008 + A.GBW009) * 100 AS burden,
	E.A43AB2000 * 1.0 / (E.A43AB2000 + E.A43AA2000) * 100 AS vacrate,
	E.B37AB2000 AS renters,
	E.B37AB2000 * 1.0 / (E.B37AB2000 + E.B37AA2000) * 100 AS tenure,
	E.B69AC2000 * 1.0 / (E.B69AC2000 + E.B69AB2000 + E.B69AA2000) * 100 AS BArate,
	E.AX7AA2000 * 1.0 / (E.AX7AB2000 + E.AX7AA2000) * 100 AS povrate,
	A.GB7001 AS medval,
	(A.GAJ009 + A.GAJ008) * 1.0 / (A.GAJ009 + A.GAJ008 + A.GAJ007 + A.GAJ006 + A.GAJ005 + A.GAJ004 + A.GAJ003 + A.GAJ002 + A.GAJ001) * 100 AS bltpre1950
	FROM nhgis0087_ds151_2000_place AS A
	JOIN nhgis0087_ts_nominal_place AS E ON A.GISJOIN = E.GJOIN2000
	WHERE GISJOIN = ?;
	''', ([v['GJOIN2000']]))
	results = cur.fetchall()
	for row in results:
		code_dict[k]['pop00'] = row[1]
		code_dict[k]['rent00'] = row[2]
		code_dict[k]['inc00'] = row[3]
		code_dict[k]['burd00'] = row[4]	
		code_dict[k]['vac00'] = row[5]	
		code_dict[k]['renterHH00'] = row[6]	
		code_dict[k]['renterPct00'] = row[7]	
		code_dict[k]['BArate00'] = row[8]
		code_dict[k]['povrate00'] = row[9]
		code_dict[k]['medHmVal00'] = row[10]
		code_dict[k]['bltPre195000'] = row[11]
#############################################################
# 2012
for k, v in code_dict.iteritems():
	cur.execute('''
	SELECT A.GISJOIN,
	A.QSPE001 AS pop,
	A.QZTE001 * 1.07 AS rent,
	B.RGRE003 * 1.07 AS income,
	(A.QZZE007 + A.QZZE008 + A.QZZE009 + A.QZZE010) * 1.0 /
	(A.QZZE001 - A.QZZE011) * 100 AS burden,
	E.A43AB2010 * 1.0 / (E.A43AB2010 + E.A43AA2010) * 100 AS vacrate,
	E.B37AB2010 AS renters,
	E.B37AB2010 * 1.0 / (E.B37AB2010 + E.B37AA2010) * 100 AS tenure,
	E.B69AC2000 * 1.0 / (E.B69AC2000 + E.B69AB2000 + E.B69AA2000) * 100 AS BArate,
	E.AX7AA2000 * 1.0 / (E.AX7AB2000 + E.AX7AA2000) * 100 AS povrate,
	A.QZ6E001 AS medval,
	(A.QY1E010 + A.QY1E009) * 1.0 / A.QY1E001 * 100 AS bltpre1950
	FROM nhgis0087_ds191_20125_2012_place AS A
	JOIN nhgis0087_ds192_20125_2012_place AS B ON A.GISJOIN = B.GISJOIN
	JOIN nhgis0087_ts_nominal_place AS E ON A.GISJOIN = E.GJOIN2012
	WHERE A.GISJOIN = ?;
	''', ([v['GJOIN2012']]))
	results = cur.fetchall()
	for row in results:
		code_dict[k]['pop125'] = row[1]
		code_dict[k]['rent125'] = row[2]
		code_dict[k]['inc125'] = row[3]
		code_dict[k]['burd125'] = row[4]
		code_dict[k]['vac125'] = row[5]	
		code_dict[k]['renterHH125'] = row[6]	
		code_dict[k]['renterPct125'] = row[7]
		code_dict[k]['BArate125'] = row[8]
		code_dict[k]['povrate125'] = row[9]
		code_dict[k]['medHmVal125'] = row[10]
		code_dict[k]['bltPre1950125'] = row[11]
#############################################################
# 2017
for k, v in code_dict.iteritems():
	cur.execute('''
	SELECT A.GISJOIN,
	A.AHY1E001 AS pop,
	A.AH5RE001 AS rent,
	B.AINJE003 AS income,
	(A.AH5XE007 + A.AH5XE008 + A.AH5XE009 + A.AH5XE010) * 1.0 /
	(A.AH5XE001 - A.AH5XE011) * 100 AS burden,
	A.AH36E003 * 1.0 / A.AH36E001 * 100 AS vacrate,
	A.AH37E003 AS renters,
	A.AH37E003 * 1.0 / A.AH37E001 * 100 AS tenure,
	(A.AH04E022 + A.AH04E023 + A.AH04E024 + A.AH04E025) * 1.0 / A.AH04E001 * 100 AS BArate,
	B.AIFOE002 * 1.0 / B.AIFOE001 * 100 AS povrate,
	A.AH53E001 AS medval,
	(A.AH4ZE011 + A.AH4ZE010) * 1.0 / A.AH4ZE001 * 100 AS bltpre1950
	FROM nhgis0087_ds233_20175_2017_place AS A
	JOIN nhgis0087_ds234_20175_2017_place AS B ON A.GISJOIN = B.GISJOIN
	WHERE A.GISJOIN = ?;
	''', ([v['GJOIN2012']]))
	results = cur.fetchall()
	for row in results:
		code_dict[k]['pop175'] = row[1]
		code_dict[k]['rent175'] = row[2]
		code_dict[k]['inc175'] = row[3]
		code_dict[k]['burd175'] = row[4]
		code_dict[k]['vac175'] = row[5]	
		code_dict[k]['renterHH175'] = row[6]	
		code_dict[k]['renterPct175'] = row[7]		
		code_dict[k]['BArate175'] = row[8]
		code_dict[k]['povrate175'] = row[9]
		code_dict[k]['medHmVal175'] = row[10]
		code_dict[k]['bltPre1950175'] = row[11]
#############################################################
con.close()
df = pd.DataFrame.from_dict(code_dict, orient='index')

start_end = [['70', '80'], ['80', '90'], ['90', '00'], ['00', '125'], ['125', '175'] ]
for x in start_end:
	start = x[0]
	end = x[1]
	df['PopChange{}_{}'.format(start, end)] = (df['pop{}'.format(end)] - df['pop{}'.format(start)]) * 1.0 / df['pop{}'.format(start)] * 100
	df['PopLoss{}_{}'.format(start, end)] = 'N'
	df.loc[df['PopChange{}_{}'.format(start, end)] < 0, 'PopLoss{}_{}'.format(start, end)] = 'Y'

outFile = "/home/eric/Documents/franklin/cost_burden/generated_data/rent_burden_data.csv"
df = df.round(2)
print df.to_csv(outFile, index_label='NHGISJOIN')

# print df.head()
print df.columns
print df[['burd80', 'burd90', 'burd00', 'burd125', 'burd175']].describe()

print df[['renterHH80', 'renterHH90', 'renterHH00', 'renterHH125', 'renterHH175']].describe()