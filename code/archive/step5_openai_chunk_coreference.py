#Sys.setenv(RETICULATE_PYTHON="/Users/elisemiller/miniconda3/bin/python")
# reticulate::py_config()
# reticulate::repl_python()

import tiktoken
import nltk
import openai
import os
import numpy as np

matched_projects = np.loadtxt("salinasbox/intermediate_data/matched_pdf_list.tsv", delimiter="\t", dtype='U', encoding = 'utf-8')

# Set up your OpenAI API key
with open('EliseKeyTwo.txt', 'r', encoding="utf-8") as f:
    key = f.read().strip()

openai.api_key = key
client = openai.OpenAI(api_key = key)


num_chunk_tokens = 5000
gpttokens = 10000

#pick up here with cleaned txt files
#test with first project
#matched_projects = matched_projects[4]
#matched_projects = [x.encode('utf-8') for x in matched_projects]
# Helper Functions


nltk.download('punkt')
nltk.download('punkt_tab')
from nltk.tokenize import sent_tokenize

def split_text_into_chunks(text, max_tokens):
    """
    Splits the content of a text file into chunks, each with fewer than max_tokens, ensuring that no sentences are split across chunks.

    Parameters:
    - text (str): Path to the input text file.
    - max_tokens (int): Maximum number of tokens per chunk.

    Returns:
    - List[str]: A list of text chunks.
    """
    # Load the encoder for the desired model (e.g., gpt-4o)
    # Make sure you have selected the correct encoding based on the model you're using
    encoding = tiktoken.encoding_for_model("gpt-4o")

    #tokenize text into sentences
    sentences = sent_tokenize(text)
    
    # Encode the text into tokens
    tokens = encoding.encode(text)
    # Split the tokens into chunks of size < max_tokens
    chunks = []
    current_chunk = ''
    for sentence in sentences:
    #add sentences to current_chunk until it's too long
        if len(encoding.encode(current_chunk + ' ' + sentence)) < max_tokens:
            current_chunk = current_chunk + ' ' + sentence
        else:
            #once the current_chunk is complete, save it to chunks and start a new current_chunk
            complete_chunk = current_chunk
            chunks.append(complete_chunk)
            #start new chunk with current sentence
            current_chunk = sentence
    #add the very last chunk to chunks even if it's not at max length
    chunks.append(current_chunk)
    return chunks

#Feb week 1 todos
#try reading in as a tsv
#filter out numbery tables and tocs with a lot of periods (?)
#run sentence tokenizer and remove empty sentences or sentences with < 8 or > 200 char

#
# tell it what to do if it can't do anything
#if no changes (if more than half of characters on this page are numbers, remove that page), pass through the input text with no additional messaging.
#if we did a character comparison and it's much shorter, keep original

instruction = f'Conduct coreference resolution on the text I am about to provide. Identify all noun phrases (mentions) that refer to the same real world entity, and return a new version of the document in which all pronouns are replaced with the corresponding noun phrase they refer to. Please try to avoid replacing instances of the pleonastic it. Note that the word "it" may refer to different real-world entities in the same document. When replacing pronouns with their corresponding noun phrase, please adjust the verb tense to make sure it is compatible with the new text. Your revised text should be identical to the input, except for the coreference resolution. That is, your expected output is somewhere around {num_chunk_tokens * 4 // 5} words. If you cannot complete the task, please just return the original input text. If you provide any commentary, please start it and end it with the keyword CHATGPTREPLY.'
assist = 'CHATGPTREPLY Here is the revised text with coreference resolution. CHATGPTREPLY '
def coreference_resolve(chunk, model):
    messages = [
        {'role': 'user', 'content': [{'type': 'text','text': instruction}]},
        {'role': 'assistant', 'content': [{'type': 'text','text': 'CHATGPTREPLY Of course, please provide the text you would like me to work on for coreference resolution. CHATGPTREPLY'}]},
        {'role': 'user', 'content': [{'type': 'text','text': chunk }]},
        {'role': 'assistant', 'content': [{'type': 'text','text': assist}]}
    ]
    response = client.chat.completions.create(
        model=model,
        messages = messages,
        temperature = 1.0,
        seed = 24,
        max_tokens = gpttokens,
        frequency_penalty = 0.0
    )
    return response.choices[0].message.content.strip()

# Main function to process a file
def process_file(file_path, output_directory):
    with open(file_path, 'r', encoding='utf-8') as file:
        input_text = file.read()

    chunks = split_text_into_chunks(input_text, num_chunk_tokens)
    print(f"There are {len(chunks)} chunks to process.")
    base_filename = os.path.splitext(os.path.basename(file_path))[0]
    for i, chunk in enumerate(chunks):
        coreference_resolved_text = coreference_resolve(chunk, 'gpt-4o')
        output_filename = f"{base_filename}_part{i+1}.txt"
        output_filepath = os.path.join(output_directory, output_filename)
        original_filename = f"{base_filename}_part{i+1}_original.txt"
        original_filepath = os.path.join(output_directory, original_filename)
        with open(output_filepath, 'w', encoding='utf-8') as output_file:
            output_file.write(coreference_resolved_text)
        print(f"Processed chunk {i+1} saved to {output_filepath}")
        with open(original_filepath, 'w', encoding='utf-8') as output_file:
            output_file.write(chunk)

# Example usage
for input_filename in matched_projects:
    print(f"Now processing {input_filename}")
    process_file(input_filename, '/Users/elisemiller/R_Projects/salinas/openai_output_files')


