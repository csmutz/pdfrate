# pdfrate

Code and data used by pdfrate and associated evasion studies:

[pdfrate] C. Smutz and A. Stavrou, “Malicious PDF Detection Using Metadata and Structural Features,” in Proceedings of the 28th Annual Computer Security Applications Conference, New York, NY, USA, 2012, pp. 239–248.

[mutual_agreement] C. Smutz and A. Stavrou, “When a Tree Falls: Using Diversity in Ensemble Classifiers to Identify Evasion in Malware Detectors,” in 21th Annual Network and Distributed System Security Symposium (NDSS), 2016.

While the complete implementation of pdfrate is not publicly available (yet), see mimicus (https://github.com/srndic/mimicus) which provides very similar results to pdfrate.

The pdfrate.com site has beeen taken down due primarily to the fact that the type of malware PDFrate was designed to detect is no longer relevant. Recent use of PDF for malware distribution involves socially engineered documents with links to malware (or credential harvesting).

## Data

The data directory contains csv files for the 2 classifiers and some of the many contemporaneous evasion studies:

[reverse_mimicry] D. Maiorca, I. Corona, and G. Giacinto, “Looking at the bag is not enough to find the bomb: an evasion of structural methods for malicious PDF files detection,” in Proceedings of the 8th ACM SIGSAC symposium on Information, computer and communications security, New York, NY, USA, 2013, pp. 119–130.

[mimicus] N. Srndic and P. Laskov, “Practical Evasion of a Learning-Based Classifier: A Case Study,” in Proceedings of the 2014 IEEE Symposium on Security and Privacy, Washington, DC, USA, 2014, pp. 197–211.

[evademl] W. Xu, Y. Qi, and D. Evans, “Automatically Evading Classifiers: A Case Study on PDF Malware Classifiers,” in 21th Annual Network and Distributed System Security Symposium (NDSS), 2016.

[parser_confusion] C. Carmony, X. Hu, H. Yin, A. Vasisht, and M. Zhang, “Extract Me If You Can:  Abusing PDF Parsers in Malware Detectors,” in 21th Annual Network and Distributed System Security Symposium (NDSS), 2016.

This data is suitable for exercises to introduce machine learning as well as studies on adversarial learning. Malicious PDFs have changed, this data is no longer useful for training classifiers for detection of current PDF-based malware.

This data is not exactly the same as that used by the original pdfrate in all cases, but it intended to be as similar as possible and have nearly identical properties. Any discrepencies should be very small. 


- These CSVs were created using the mimicus feature extractor
- All files used in these CSVs are available (or at least were available) on Virustotal as well as other sources.
  - The university classifier changed multiple times thoughout the operation of pdfrate.com and it contained files not publicly available. The data provided seeks to replicate this classifier qualitatively but many specific samples had to be substituted
  - The university classifier CSV has been split into 4 pieces to fit under common file upload/attachment limits. Simply concatenate this file to reconstruct the complete CSV


## Exercise

Basic exercise using PDFrate data and mimicus code

- Extract features, train and use model
- What features are most heavily used?
- Which samples in training are redundant?
- Replicate or study specific attack methods
- Can you construct evasive sample?
- Construct other model types, compare
- Visualize classifier (construct trees)
- Why is University better than Contagio?
- Explain rationale for a given prediction

```
#create test csvs, samples is directory with pdfs:
./featureextractor.py --ben <(find samples -type f) eval.csv

#load dataset
import mimicus.tools.datasets
X, y, names = mimicus.tools.datasets.csv2numpy("train.csv")


#train model
from sklearn.ensemble import RandomForestClassifier as RF
model = RF(n_estimators=100, n_jobs=-1, oob_score=True)
model.fit(X,y)

#info about model
model.oob_score_
model.feature_importances_

#predict, predict showing votes
model.predict(X)
model.predict_proba(X)

#leaf nodes
model.apply(X)

#serialize/deserialize classifier
import pickle
pickle.dump(model, open("example.model", 'wb+'))
model = pickle.load(open("example.model", 'rb+'))
```  
