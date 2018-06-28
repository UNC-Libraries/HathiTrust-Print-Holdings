require_relative '../lib/hathi_print_holdings.rb'

WORKDIR = 'output/'

query = <<~SQL
select distinct 'b' || rm.record_num || 'a' as bnum
            from sierra_view.bib_record b
              inner join sierra_view.bib_record_location bl on bl.bib_record_id = b.id
              inner join sierra_view.bib_record_property bp on bp.bib_record_id = bl.bib_record_id
              inner join sierra_view.record_metadata rm on rm.id = b.id
            where bp.material_code in ('a', 'c', 'e', 'p', 't')
              and b.cataloging_date_gmt is not null
              and bl.location_code not in ('dg', 'dr', 'dy', 'eb', 'ed', 'es', 'yh', 'wa')
SQL

SierraDB.make_query(query)

i = 0
filenum = 0
bnums_per_file = 200000
ofile = nil
SierraDB.results.entries.each do |entry|
  unless ofile
    filenum += 1
    filesuffix = filenum.to_s.rjust(3, '0')
    filename = WORKDIR + "bnums.#{filesuffix}.list"
    ofile = File.open(filename, 'w')
  end

  ofile << "#{entry['bnum']}\n"
  i += 1

  if i == bnums_per_file
    ofile.close
    ofile = nil
    i = 0
  end
end
ofile.close
SierraDB.close
