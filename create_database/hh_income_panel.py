'''
make panel dataset - longwise -
with binned income data from NHGIS
for each place, for each year, collect
data for each bin
'''

import sqlite3 as sql
import pandas as pd
from collections import OrderedDict
import csv

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
	FROM ts_nominal_place
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
#############################################################
years = ['1990', '2000', '125', '175']

outFile = "/home/eric/Documents/franklin/cost_burden/generated_data/HH_income_long.csv"
with open(outFile, 'wb') as f:
	writer = csv.writer(f)
	header = [
		'GISJOIN',
		'PLACE',
		'YEAR',
		'AA',
		'AB',
		'AC',
		'AD',
		'AE',
		'AF',
		'AG',
		'AH',
		'AI',
		'AJ',
		'AK',
		'AL',
		'AM',
		'AN',
		'AO',
		]
	writer.writerow(header)

	for k, v in code_dict.iteritems():

		for y in years:

			if y!='175':

				bin_dict = {
					'AA': {'LB': 0, 'UB': 9999},
					'AB': {'LB': 10000, 'UB': 14999},
					'AC': {'LB': 15000, 'UB': 19999},
					'AD': {'LB': 20000, 'UB': 24999},
					'AE': {'LB': 25000, 'UB': 29999},
					'AF': {'LB': 30000, 'UB': 34999},
					'AG': {'LB': 35000, 'UB': 39999},
					'AH': {'LB': 40000, 'UB': 44999},
					'AI': {'LB': 45000, 'UB': 49999},
					'AJ': {'LB': 50000, 'UB': 59999},
					'AK': {'LB': 60000, 'UB': 74999},
					'AL': {'LB': 75000, 'UB': 99999},
					'AM': {'LB': 10000, 'UB': 124999},
					'AN': {'LB': 125000, 'UB': 149999},
					'AO': {'LB': 150000, 'UB': float('inf')}
					}

				bin_dict = OrderedDict(sorted(bin_dict.items(), key=lambda t: t[0]))
				for bin_k, bin_v in bin_dict.iteritems():
					cur.execute('''
						SELECT B71{}{}
						FROM ts_nominal_place
						WHERE GJOIN2000 = ?;
						'''.format(bin_k, y), ([k]))
					result = cur.fetchone()
					try:
						bin_dict[bin_k]['count'] = result[0]
					except:
						print k, v
						bin_dict[bin_k]['count'] = -99
				row = [k, v['PLACE'], y]
				for bin_k, bin_v in bin_dict.iteritems():
					row.append(bin_v['count'])

				writer.writerow(row)

			elif y=='175':

				bin_dict = {
					'002': {},
					'003': {},
					'004': {},
					'005': {},
					'006': {},
					'007': {},
					'008': {},
					'009': {},
					'010': {},
					'011': {},
					'012': {},
					'013': {},
					'014': {},
					'015': {},
					'016': {},
					'017': {}
					}

				bin_dict = OrderedDict(sorted(bin_dict.items(), key=lambda t: t[0]))
				for bin_k, bin_v in bin_dict.iteritems():
					cur.execute('''
						SELECT AH1OE{}
						FROM ds233_20175_2017_place
						WHERE GISJOIN = ?;
						'''.format(bin_k), ([k]))
					result = cur.fetchone()
					try:
						bin_dict[bin_k]['count'] = result[0]
					except:
						print k, v
						bin_dict[bin_k]['count'] = -99
			
				row = [k, v['PLACE'], y]
				bin_dict['016']['count'] += bin_dict['017']['count']
				for bin_k, bin_v in bin_dict.iteritems():
					if bin_k=='017':
						pass
					else:
						row.append(bin_v['count'])
				writer.writerow(row)


con.close()
print "done"