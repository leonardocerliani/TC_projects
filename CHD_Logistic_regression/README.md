## Prediction of 10-year risk of coronary heart disease

A logistic regression approach to investigate the [Framingham dataset](https://www.kaggle.com/datasets/aasheesh200/framingham-heart-study-dataset)

The Framingham coronary heart disease (CHD) study has been running for several decades. Its aim is to identify physical dispositions and life habits which can result in a risk of developing CHD in a 10-year time.

### Quick links
- [Analysis report](https://tc-logistic-regression.netlify.app/#CHD_Prediction_app) which includes also the R code and a shiny app implementing the model[^1].

- [Results presentation](presentation_framingham.pdf)


[^1]: The use of the app is conditional to the acceptance of the displayed disclaimer which appears when the page is loaded 

### Main Results

- Since we are trying to predict the risk of a serious health condition - which can have profound lifestyle and economical impact on the life of the patients - the analysis was aimed at maximising sensitivity even at the cost of inflating false negatives.

The final model correctly predicts risk of CHD in 10 years in 83% of the people who are actually at risk (i.e. sensitivity) when the threshold for binary classification is set to 0.1

This model is simple, containing only easily retrievable variables: sex, age, systolic blood pressure, glucose and # cigarettes per day

Assumption of blood pressure medicaments does not appear to decrease the odds of CHD

The explained variance is low (17% max). Other unexplored variables such as alcohol consumption, stress, wealth, might improve fit and performance

Sex has probably a relatively low impact, as revealed by a balanced sample
