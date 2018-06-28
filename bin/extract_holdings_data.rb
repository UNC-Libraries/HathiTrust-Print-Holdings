
require 'fileutils'
require 'csv'
require 'yaml'
require_relative '../lib/hathi_print_holdings.rb'

bnum_file = ARGV[0]
begin
  SierraDB.connect_as(cred: 'tdfull.secret')
  SierraDB.conn.conninfo
rescue PG::ConnectionBad
  abort("#{Time.now}    #{bnum_file}   aborted -- too many connections")
end
timestart = Time.now
puts "#{timestart}    #{bnum_file}   started"


WORKDIR = 'output/'

filenum = bnum_file[/\d+/]

svmono = CSV.open(WORKDIR + "svmono.#{filenum}.tsv", 'w', col_sep: "\t")
mvmono = CSV.open(WORKDIR + "mvmono.#{filenum}.tsv", 'w', col_sep: "\t")
serial = CSV.open(WORKDIR + "serial.#{filenum}.tsv", 'w', col_sep: "\t")
exclude = CSV.open(WORKDIR + "exclude.#{filenum}.tsv", 'w', col_sep: "\t")
warning = CSV.open(WORKDIR + "warn.#{filenum}.tsv", 'w', col_sep: "\t")

HathiPrintHoldings::Writing.set_files(exclude: exclude, warn: warning)

bibcount = 0
File.foreach("#{WORKDIR}/#{bnum_file}", headers: true) do |bnum|
  bibcount += 1
  bib = SierraBib.new(bnum.rstrip)
  bnum = bib.bnum_trunc
  htbib = HathiPrintHoldings::Assess::Bib.new(bib)

  next unless htbib.eligible?

  #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  # If it is a serial, go ahead and write output.
  # We don't even need to look at items and holdings!
  #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  if htbib.ht_category == 'serial'
    serial << [htbib.oclcnum, bnum, htbib.ht_issn, htbib.ht_govdoc_code]
    next
  end 

  #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  # Print HT data for any eligible items to
  #   appropriate monograph files!
  #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  htbib.eligible_items&.each do |item|
    holdstat = item.holding_status
    condition = item.condition
    volnum = item.volumes&.first&.strip
    if htbib.ht_category == 'sv mono'
      svmono << [htbib.oclcnum, bnum, holdstat, condition, htbib.ht_govdoc_code]
    elsif htbib.ht_category == 'mv mono'
      mvmono << [htbib.oclcnum, bnum, holdstat, condition, volnum, htbib.ht_govdoc_code]
    end
  end
end

svmono.close
mvmono.close
serial.close
exclude.close
warning.close

timestop = Time.now
File.write(
  WORKDIR + "stat.#{filenum}.tsv",
  [ARGV[0], bibcount, timestart, timestop].join("\t") + "\n"
)
puts "#{timestop}    #{bnum_file} finished"