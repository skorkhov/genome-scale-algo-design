using Random
using StatsBase

protein_codon_dict = Dict(
    'A' => ["GCT", "GCC", "GCA", "GCG"], 
    'R' => ["CGT", "CGC", "CGA", "CGG", "AGA", "AGG"],
    'N' => ["AAT", "AAC"],
    'D' => ["GAT", "GAC"],
    'C' => ["TGT", "TGC"],
    'Q' => ["CAA", "CAG"],
    'E' => ["GAA", "GAG"],
    'G' => ["GGT", "GGC", "GGA", "GGG"], 
    'H' => ["CAT", "CAC"],
    'I' => ["ATT", "ATC", "ATA"], 
    'L' => ["CTT", "CTC", "CTA", "CTG", "TTA", "TTG"],
    'K' => ["AAA", "AAG"],
    'M' => ["ATG"], 
    'F' => ["TTT", "TTC"],
    'P' => ["CCT", "CCC", "CCA", "CCG"], 
    'S' => ["TCT", "TCC", "TCA", "TCG", "AGT", "AGC"], 
    'T' => ["ACT", "ACC", "ACA", "ACG"], 
    'W' => ["TGG"], 
    'Y' => ["TAT", "TAC"], 
    'V' => ["GTT", "GTC", "GTA", "GTG"]
)

function translate(codon)
    mask = [codon in val for val in values(protein_codon_dict)]
    protein = collect(keys(protein_codon_dict))[findall(mask)]
    protein[1]
end

# create codon frequency list with random generator: 
function randcodonfreq(codon_dict)
    Random.seed!(42)
    codons = reduce(vcat, values(codon_dict))
    occurences = Random.rand(UInt8, length(codons))
    Dict(codons .=> Int.(occurences))
end

codon_freq = randcodonfreq(protein_codon_dict)



function exercise_11(pseq)
    codon_seq = [protein_codon_dict[i] for i in pseq]
    comb = (x, y) -> [i*j for i in x for j in y]
    reduce(comb, codon_seq)
end



function exercise_12(pseq, freq = codon_freq)
    function sample_codon(protein)
        codons = protein_codon_dict[protein]
        weights = StatsBase.Weights([freq[codon] for codon in codons])
        sample(codons, weights)
    end

    [sample_codon(p) for p in pseq]
end


#=
Given all exons, extract every pair of consecutive codons.

For every pair of consecutive codons, compute:
  - observed number of occurrences (1)
  - expected number of occurences, given the same protein sequence (2)
  - ratio (1)/(2)

Given S that encodes P and f(S)=mean(z(XY)) for all consecutive pairs XY in S, 
compute codon permutation S' of S such that f(S') < f(S).
=#
function exercise_13(exon)
    codons = [exon[i:i+2] for i in 1:3:length(exon) if i+2 <= length(exon)]
    codon_pairs = zip(codons[1:end-1], codons[2:end])
    codon_pairs_freq = StatsBase.countmap(codon_pairs)
    codon_pairs_prob = Dict(keys(codon_pairs_freq) .=> collect(values(codon_pairs_freq)) / sum(values(codon_pairs_freq)))
    @show collect(codon_pairs)

    aacids = translate.(codons)
    aacid_pairs = zip(aacids[1:end-1], aacids[2:end])
    aacid_pairs_freq = StatsBase.countmap(aacid_pairs)
    aacid_pairs_prob = Dict(keys(aacid_pairs_freq) .=> collect(values(aacid_pairs_freq)) / sum(values(aacid_pairs_freq)))
    @show collect(aacid_pairs)

    function expected_codon_pair_prob(codon_pair, aacid_pairs_prob = aacid_pairs_prob)
        aacid_pair = translate.(codon_pair)

        # codon_redundancy = how many codon pairs encode an amino acid pair: 
        codon_redundancy = prod([length(protein_codon_dict[aa]) for aa in aacid_pair])
        codon_pair_prob = aacid_pairs_prob[aacid_pair] / codon_redundancy

        codon_pair_prob
    end
    
    expected_probs = Dict(keys(codon_pairs_prob) .=> expected_codon_pair_prob.(keys(codon_pairs_prob)))
    observed_vs_expected_ratio = Dict(keys(codon_pairs_prob) .=> collect(values(codon_pairs_prob)) ./ values(expected_probs))

    observed_vs_expected_ratio
end
