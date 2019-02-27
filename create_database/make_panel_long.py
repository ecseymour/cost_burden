'''
put each year of data on a single row
'''
import pandas as pd

inFile = "/home/eric/Documents/franklin/cost_burden/generated_data/rent_burden_data.csv"
df = pd.read_csv(inFile)
df['inc90'] = None

years = ['80', '90', '00', '125', '175']

for y in years:
	print y
	cols = ['NHGISJOIN', 'PLACE', 'STATE', 
			'pop{}'.format(y), 
			'rent{}'.format(y), 
			'inc{}'.format(y), 
			'burd{}'.format(y), 
			'vac{}'.format(y), 
			'renterHH{}'.format(y), 
			'renterPct{}'.format(y),
			'BArate{}'.format(y),
			'povrate{}'.format(y),
			'medHmVal{}'.format(y),
			'bltPre1950{}'.format(y)
			]
	if y=='80':
		final_df = df[cols].copy(deep=True)
		final_df.columns = ['NHGISJOIN', 'PLACE', 'STATE', 
			'pop', 
			'rent', 
			'inc', 
			'burd',
			'vac',
			'renterHH',
			'renterPct',
			'BArate',
			'povrate',
			'medHmVal',
			'bltPre1950'
			]
		final_df['year'] = '1980'
		final_df.index = final_df['NHGISJOIN'] + final_df['year']
		print final_df.head()
	else:
		temp = df[cols].copy(deep=True)
		temp.columns = ['NHGISJOIN', 'PLACE', 'STATE', 
			'pop', 
			'rent', 
			'inc', 
			'burd',
			'vac',
			'renterHH',
			'renterPct',
			'BArate',
			'povrate',
			'medHmVal',
			'bltPre1950'
			]
		if y=='90':
			y = '1990'
		elif len(y)==3:
			y = '20{}'.format(y[:2])
		else:
			y = '20{}'.format(y)
		temp['year'] = y		
		temp.index = temp['NHGISJOIN'] + temp['year']
		print temp.head()
		final_df = final_df.append(temp)

print "+" * 50
print final_df.head()

print final_df.groupby('year').size()

outfile = "/home/eric/Documents/franklin/cost_burden/generated_data/rent_burden_data_long.csv"

print final_df.sort_values(['NHGISJOIN', 'year']).head()
final_df.sort_values(['NHGISJOIN', 'year']).to_csv(outfile, index_label='NHGISCODE_YEAR')