from MetaTrader5 import *
from datetime import date
import pandas as pd
from pprint import pprint
import numpy as np
import matplotlib.pyplot as plt
import scipy as sp
import scipy.fftpack
from scipy import signal
import progressbar
import time
import random
import math
from sklearn.model_selection import train_test_split
from pandas.plotting import register_matplotlib_converters
register_matplotlib_converters()

def get_ct():
  ctr = 0
  with open('ctr.txt', 'r') as file:
    ctr =  int(file.read())
  ctr = ctr + 1
  with open('ctr.txt', 'w') as file:
    file.write(str(ctr))
  return ctr

SEQ_LEN = 300
FUTURE_PERIOD_PREDICT = 15
EPOCHS = 1000
BATCH_SIZE = 32
COUNTER = get_ct()
TIMEFRAME = MT5_TIMEFRAME_M1
RATE_NR = 10000
NAME = f"NR{COUNTER}-{SEQ_LEN}-SEQ-{FUTURE_PERIOD_PREDICT}-PRED-{TIMEFRAME}-TFRAM-{RATE_NR}-RATES"

MT5Initialize()
MT5WaitForTerminal()

print(MT5TerminalInfo())
print(MT5Version())

rates = MT5CopyRatesFromPos('EURUSD', TIMEFRAME, 0, 100000)

ratelist = []
for rate in rates:
  ratelist.append([rate.time, rate.close])

data = pd.DataFrame(ratelist, columns = ["time", "close"])

#data.to_pickle('save.pkl')
#data = pd.read_pickle('save.pkl')

print ("First sample: " + str(min(data["time"])))

#def wd(d):
#  return d.weekday()

#data["weekday"] = data.apply(lambda row : wd(row["time"]), axis=1)

def butter_filter(data, freq_sampl, freq_cutoff):
  w = freq_cutoff / (freq_sampl / 2) # Normalize the frequency
  b, a = signal.butter(5, w, 'low')
  return signal.filtfilt(b, a, data["close"])

data["filtered15"] = butter_filter(data, 2000, 15)
print ("Filtering done")

data["derivative"] = np.gradient(data["filtered15"])
abs_max = max(abs(data["derivative"]))
print ("Derivation done")
data["derivative"] = data["derivative"] / abs_max
print ("Normatization done by: " + str(abs_max))

data.dropna(inplace=True)

fig, ax1 = plt.subplots()

#ax1.plot(data['time'], data['close'], label="close")
#ax1.plot(data['time'], data['filtered15'], label="filtered15")

color2 = "red"
color3 = "blue"
ax2 = ax1.twinx()
#ax2.plot(data['time'], data['derivative'], label="derivative", color=color2)
ax2.tick_params(axis='y', labelcolor=color2)
fig.tight_layout()

#plt.show()

del data["filtered15"]

#pprint(data)

print ("Splitting dataset")
times = data.index.values
last_10pct = times[-int(0.05*len(data))]
validation_data = data[(data.index >= last_10pct)]
validation_data.reset_index(inplace=True)
data = data[(data.index < last_10pct)]
print ("Dataset split")

def preprocess_df(df):
  print ("Generating batches from sequential input")
  x, y = [], []
  with progressbar.ProgressBar(max_value=len(df) - SEQ_LEN - FUTURE_PERIOD_PREDICT) as bar:
    for i in range(len(df)):
      # find the end of this pattern
      end_ix = i + SEQ_LEN
      # check if we are beyond the sequence
      if end_ix + FUTURE_PERIOD_PREDICT >= len(df):
        break
      # gather input and output parts of the pattern
      seq_x, seq_y = df["derivative"][i:end_ix], df["derivative"][end_ix:end_ix + FUTURE_PERIOD_PREDICT]
      x.append(seq_x)
      y.append(seq_y)
      bar.update(i)
  z = list(zip(x, y))
  print ("Shuffling generated batches")
  random.shuffle(z)
  x, y = zip(*z)
  print ("Shuffling done")
  return np.array(x), np.array(y)

x_train, y_train = preprocess_df(data)
x_test, y_test = preprocess_df(validation_data)

#print ("Splitting dataset")
#x_train, x_test, y_train, y_test = train_test_split(data_x, data_y, test_size=0.1)
#print ("Dataset split")
x_train = x_train.reshape(len(x_train), SEQ_LEN, 1)
x_test = x_test.reshape(len(x_test), SEQ_LEN, 1)
print ("Reshaping done")

import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, LSTM, BatchNormalization
from tensorflow.keras.callbacks import TensorBoard
from tensorflow.keras.callbacks import ModelCheckpoint

model = Sequential()
model.add(LSTM(SEQ_LEN + 1, input_shape=([SEQ_LEN, 1]), activation='relu'))

hidden_cnt = int(math.sqrt((SEQ_LEN + 1) * FUTURE_PERIOD_PREDICT))
model.add(Dense(hidden_cnt, activation='relu'))

model.add(Dense(FUTURE_PERIOD_PREDICT))

model.summary()

opt = tf.keras.optimizers.Adam(lr=0.00001)

model.compile(
  loss='mse',
  optimizer=opt,
  metrics=['mae', 'mse']
)

tensorboard = TensorBoard(log_dir="logs\{}".format(NAME), histogram_freq=1)
filepath = "models\{}".format(NAME) + "-{epoch:03d}"
print(filepath)
checkpoint = ModelCheckpoint(filepath, monitor='val_loss', verbose=1, save_best_only=False, mode='min')
history = model.fit(
  x_train, y_train,
  batch_size=BATCH_SIZE,
  epochs=EPOCHS,
  validation_data=(x_test, y_test),
  callbacks=[tensorboard, checkpoint],
)

score = model.evaluate(x_test, y_test, verbose=0)
print('Test loss:', score[0])
print('Test accuracy:', score[1])

model.save("models\{}".format(NAME))
with open("models\{}".format(NAME) + "\\norm", "x") as f:
  f.write(str(abs_max))

def predict_signal(m, input, norm, t):
  reps = t // FUTURE_PERIOD_PREDICT
  data_1d = input
  for i in range(reps):
    data_3d = data_1d[-SEQ_LEN:]
    data_3d = data_3d.reshape(1, SEQ_LEN, 1)
    pred_2d = model.predict(data_3d)
    pred_1d = pred_2d.reshape(FUTURE_PERIOD_PREDICT)
    data_1d = np.concatenate((data_1d, pred_1d))
  return data_1d
