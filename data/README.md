# Data

The raw CSV files used in this project are not included in this repository.

**Source:** [League of Legends World Championship Dataset on Kaggle](https://www.kaggle.com/datasets/maulikgajera/league-of-legends-world-championship-dataset)

**To reproduce this project:**
1. Download the dataset from the Kaggle link above
2. You should have 9 CSV files matching the table names referenced in `queries.sql`
3. Create the tables using the schema referenced in `queries.sql`
4. Import each CSV into its corresponding table using pgAdmin's Import/Export Data tool (or `\copy` in psql)
