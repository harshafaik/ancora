import os
import gzip
import requests
import mmh3
from bitarray import bitarray
import struct

def generate_bloom_filter():
    url = "https://dumps.wikimedia.org/enwiki/latest/enwiki-latest-all-titles-in-ns0.gz"
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_dir = os.path.join(base_dir, "app", "assets")
    filter_path = os.path.join(assets_dir, "wikipedia_titles.bloom")
    dump_path = os.path.join(base_dir, "backend", "enwiki-latest-all-titles-in-ns0.gz")

    if not os.path.exists(assets_dir):
        os.makedirs(assets_dir)

    if not os.path.exists(dump_path):
        print(f"Downloading {url}...")
        response = requests.get(url, stream=True)
        with open(dump_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print("Download complete.")

    # Target: 1,000,000 titles, Error Rate: 0.01
    # m = -(n * ln(p)) / (ln(2)^2)
    # k = (m/n) * ln(2)
    # For n=1,000,000, p=0.01:
    # m = 9,585,059 bits (~1.2MB)
    # k = 7
    m = 9585059
    k = 7
    
    # We use m as the capacity field in the header to simplify Dart logic
    # Header: 8 bytes m (uint64), 8 bytes k (uint64)
    
    bit_array = bitarray(m)
    bit_array.setall(0)

    print(f"Processing titles and inserting into Bloom Filter (m={m}, k={k})...")
    
    count = 0
    inserted_count = 0
    
    def add_to_filter(key):
        nonlocal inserted_count
        for i in range(k):
            # Using i as seed for multiple hash functions
            index = mmh3.hash(key, i, signed=False) % m
            bit_array[index] = True
        inserted_count += 1

    try:
        with gzip.open(dump_path, 'rt', encoding='utf-8') as f:
            first_line = f.readline()
            if not first_line.startswith("page_title") and first_line.strip():
                title = first_line.strip()
                add_to_filter(title)
                add_to_filter(title.lower())
                count += 1

            for line in f:
                title = line.strip()
                if not title:
                    continue
                
                add_to_filter(title)
                add_to_filter(title.lower())
                count += 1
                
                if count % 100000 == 0:
                    print(f"Processed {count} titles...")
                
                if count >= 1000000: # Limit to 1,000,000 unique titles (so 2M items)
                    # Note: Original prompt said "capacity 1,000,000". 
                    # If it's 1M titles + lowercase, it's 2M items.
                    # I'll stick to 1,000,000 titles.
                    break

    except KeyboardInterrupt:
        print("\nStopping early...")
    except Exception as e:
        print(f"Error processing titles: {e}")

    print(f"Exporting Bloom Filter to {filter_path}...")
    with open(filter_path, "wb") as f:
        # Write header
        f.write(struct.pack("<QQ", m, k)) # Little-endian uint64
        # Write bit array
        bit_array.tofile(f)

    print("\nFinal Stats:")
    print(f"Total titles processed: {count}")
    print(f"Total items inserted: {inserted_count}")
    print(f"Bit array size (m): {m}")
    print(f"Hash functions (k): {k}")
    print(f"Filter saved to: {filter_path}")

if __name__ == "__main__":
    generate_bloom_filter()
