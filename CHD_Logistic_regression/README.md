## Prediction of 10-year risk of coronary heart disease

A logistic regression approach to investigate the [Framingham dataset](https://www.kaggle.com/datasets/aasheesh200/framingham-heart-study-dataset)

The Framingham coronary heart disease (CHD) study has been running for several decades. Its aim is to identify physical dispositions and life habits which can result in a risk of developing CHD in a 10-year time.

### Quick links
- [Analysis report](https://tc-logistic-regression.netlify.app/) which includes also the R code and a shiny app implementing the model[^1].

- [Results presentation](presentation_framingham.pdf)


[^1]: The use of the app is conditional to the acceptance of the displayed disclaimer which appears when the page is loaded 

### Main Results

- **The final model correctly predicts risk of CHD in 10 years in 83% of the people who are actually at risk (sensitivity)** when the threshold for binary classification is set at 0.1

- The choice of this threshold (0.1) leads to many false positives, however given the potential life-threatening implications of false negatives - and the relatively simple continous monitoring of the patients with positive prediction - the choice obviously falls on maximising the sensitivity.

- **The model is simple, contaning only easily retrievable variables**: sex, age, systolic blood pressure, glucose and smoking habits

- Assumption of blood pressure medicaments does _not_ appear to decrease the odds of CHD risk

- The amount of explained variance is moderate (17%). Other unexplored variables such as alcohol consumption, stress and wealth (among others) might improve model fit and performance.

