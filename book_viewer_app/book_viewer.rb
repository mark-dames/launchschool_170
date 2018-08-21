require "sinatra"
require "sinatra/reloader" if development?

def each_chapter
  @contents.each_with_index do |name, index|
    number = index + 1
    contents = File.read("data/chp#{number}.txt")
    yield number, name, contents
  end
end

def chapters_matching(query)
  results = []

  return results unless query

  each_chapter do |number, name, contents|
    matches = {}
    contents.split("\n\n").each_with_index do |paragraph, index|
      matches[index] = paragraph if paragraph.include?(query)
    end
    results << {number: number, name: name, paragraphs: matches} if matches.any?
  end

  results
end

before do
  @contents = File.readlines("data/toc.txt")
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").each_with_index.map do |line, index|
      "<p id=paragraph#{index}>#{line}</p>"
    end.join
  end
  
  def highlight(text, term)
    text.gsub(term, %(<strong>#{term}</strong>))
  end
end

not_found do
  redirect "/"
end

get "/" do
  @title = "The Adventures of Sherlock Holmes"
  
  erb :home
end

get "/chapters/:number" do
  chapter_number = params[:number].to_i
  chapter_name = @contents[chapter_number - 1]
  
  redirect "/" unless (1..@contents.size).cover? chapter_number
  
  @title = "Chapter: #{chapter_number}: #{chapter_name}"
  
  content = File.read("data/chp#{chapter_number}.txt")
  @chapter = in_paragraphs(content)

  erb :chapter
end

get "/search" do
  @results = chapters_matching(params[:query])
  
  erb :search
end


