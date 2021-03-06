require 'Nokogiri'
require 'Faraday'
require 'byebug'
require 'watir'
require 'watir-scroll'
require 'csv'

def bulldog_scraper
    url = "https://bulldogjob.pl/companies/jobs"
    conn = Faraday.new
    unparsed_page = conn.get url
    parsed_page = Nokogiri::HTML(unparsed_page)
    job_offers = parsed_page.css('ul.results-list li')
    page = 1
    last_page = parsed_page.css('nav.text-center ul.pagination').text.split(' ').pop.to_i 
    jobs = Array.new
    while page <= last_page
        pagination_url = "https://bulldogjob.pl/companies/jobs?page=#{page}"
        pagination_unparsed_page = conn.get pagination_url
        pagination_parsed_page = Nokogiri::HTML(pagination_unparsed_page.body)
        pagination_job_offers = pagination_parsed_page.css('ul.results-list li.results-list-item')
        pagination_job_offers.each do |job_offer|
            job = {
                title: job_offer.css('h2.result-header').text.strip,
                location: job_offer.css('div.result-desc p.result-desc-meta span.pop-mobile').text.strip,
                company: job_offer.css('div.result-desc p.result-desc-meta span.pop-black').text.strip,
                salary: job_offer.css('div.result-desc p.result-desc-meta span.pop-green').text.strip,
                tags: job_offer.css('div.result-desc li.tags-item').text.split(/\n+/).join(" "),
                url: job_offer.css('a')[0].attributes['href'].value
            }
            jobs << job if job[:title] != ""
        end
        page += 1
    end
    return jobs
end


def justjoin_scraper
    browser = Watir::Browser.new :chrome, headless: true
    browser.goto("https://justjoin.it/")
    last_offer_age = ""
    age_days = 1
    while last_offer_age.to_i < age_days
        offers_list = browser.element(css: 'ul.offers-list')
        offers_list.scroll.to :bottom
        offers = offers_list.elements(css: 'li.offer-item')
        last_offer_age = offers.last.element(css: 'span.age').text.chr
        last_offer_age = 0 if last_offer_age == "N"
    end
    jobs = Array.new
    offers.each do |job_offer|
        tags_arr = []
        tag_elements = job_offer.elements(css: 'span.tag').to_a
        tag_elements.each do |tag_element|
            tags_arr << tag_element.inner_text
        end
        job = {
            title: job_offer.span(class: 'title').text,
            location: job_offer.span(class: 'company-address').text.split.last,
            company: job_offer.span(class: 'company-name').text[2..-1],
            salary: job_offer.span(class: 'salary-row').text,
            tags: tags_arr.join(', '),
            url: job_offer.a.href
        }
        jobs << job if job[:title] != "" && job_offer.element(css: 'span.age').text.chr.to_i < age_days
    end
    return jobs
end

all_offers = bulldog_scraper + justjoin_scraper

CSV.open("./job_offers.csv", "wb") do |csv|
    csv << all_offers_filtered.first.keys
    all_offers_filtered.each do |offer|
        csv << offer.values
    end
end