#Sys.setenv(RETICULATE_PYTHON="/Users/elisemiller/miniconda3/bin/python")

import openai
import os
import numpy as np
import tiktoken

# Set up your OpenAI API key
with open('EliseKeyTwo.txt', 'r', encoding="utf-8") as f:
    key = f.read().strip()

openai.api_key = key
client = openai.OpenAI(api_key = key)

num_chunk_tokens = 1000
gpttokens = 8000
# Function to collect files from a directory
def collect_files(directory):
    collected_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            collected_files.append(file_path)
    return collected_files

directory_to_search = "/Users/elisemiller/R_Projects/salinas/text_as_datatable"
all_files = collect_files(directory_to_search)

# Function to check for substrings in a string
def check_for_substrings(string, substrings):
    return any(substring in string for substring in substrings)

# Import substrings to check
with open('solarwind_EISnumbers.txt', encoding="utf-8") as f:
    substrings_to_check = [line.strip() for line in f]

bool_match = np.array([check_for_substrings(file, substrings_to_check) for file in all_files])

# Filter matched files
matched_projects = np.array(all_files)[bool_match]

#test with first project
matched_projects = matched_projects[2]
matched_projects = [x.encode('utf-8') for x in matched_projects]
# Helper Functions
import tiktoken
import nltk

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



instruction = f'Conduct coreference resolution on the text I am about to provide. Identify all noun phrases (mentions) that refer to the same real world entity, and return a new version of the document in which all pronouns are replaced with the corresponding noun phrase they refer to. Please try to avoid replacing instances of the pleonastic it. Note that the word "it" may refer to different real-world entities in the same document. When replacing pronouns with their corresponding noun phrase, please adjust the verb tense to make sure it is compatible with the new text. Your revised text should be identical to the input, except for the coreference resolution. That is, your expected output is somewhere around {num_chunk_tokens * 4 // 5} words.'
assist = 'Here is the revised text with coreference resolution.'
def coreference_resolve(chunk, model):
    messages = [
        {'role': 'user', 'content': [{'type': 'text','text': instruction}]},
        {'role': 'assistant', 'content': [{'type': 'text','text': 'Of course, please provide the text you would like me to work on for coreference resolution.'}]},
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

```
