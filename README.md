# Files for Survival 101 Classes

#### by Pasha Roberts

## Context
Demo code supporting various presentations and classes about Prediction with Survival Analytics, including:

- Predictive Analytics World 2017 ["How to Use Survival Analytics to Predict Employee Turnover"](http://www.predictiveanalyticsworld.com/workforce/2017/agenda_overview.php)
- UC Irvine course ["Predictive HR and Workforce Analytics"](https://ce.uci.edu/courses/sectiondetail.aspx?year=2016&term=Fall&sid=00500)

## The Slides

The course slides for PAW Workforce are now online in this repository.
The easiest way to view them is to look at the PDF: [slides/pawfw2017.pdf](slides/pawfw2017.pdf).

They are actually HTML slides produced with [remark](https://github.com/gnab/remark) - if you clone this repository and open [slides/pawfw2017.html](slides/pawfw2017.html) in a browser, then you'll see a nice powerpoint-like presentation in your browser.
Type "?" to get the list of commands that you can use while walking through the slides.
Much better than powerpoint if you are comfortable with text.

## The Code
The PAW code is in [code/survival101.R](code/survival101.R).
The functions include:

- `demoETL()` walks through the conversion of raw HR data into a data frame usable for survival analytics.
- `demoPrediction()` walks through creating a survival curve, predicting a proportional hazard model, and validating the model.
- `genAttritionData()` generates a random attrition dataset.
- `genRandomSpans()` generates random employment spans.
- `survFitData()` transforms a `survival::survfit` object into a usable R `data.frame`.
- `plotSurvFit()` makes a `ggplot2` plot of a survival curve
- `plotSurvAUC()` makes a `ggplot2` plot of an AUC curve
