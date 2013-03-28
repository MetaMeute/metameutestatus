xml.instruct! :xml, :version=>"1.0", :encoding=>"utf-8"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title @page_title
    xml.description @page_title + " Feed"
    xml.link request.url

    @data.each do |d|
      xml.item do
        if d.has_key? 'door_open'
          xml.title (d['door_open'].to_i==1?"open":"closed")
        else
          xml.title d['message']
        end
        xml.link "#{request.url.chomp request.path_info}"  
        xml.guid "#{request.url.chomp request.path_info}/#{d['id']}"  
        xml.pubDate Time.parse(d['timestamp'].to_s + "UTC").rfc822
      end  
    end  
  end  
end  
