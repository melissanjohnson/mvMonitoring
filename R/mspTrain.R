#' Multi-State Adaptive-Dynamic Process Training
#'
#' @description This function performs Multi-State Adaptive-Dynamic PCA on a
#' data set with time-stamped observations.
#'
#' @param data an xts data matrix
#' @param labelVector class label vector (as logical or finite numeric)
#' @param trainObs the number of observations upon which to train the algorithm
#' @param updateFreq the algorithm update frequency (defaulting to half as many
#' observations as the training frequency)
#' @param Dynamic Should the PCA algorithm include lagged variables? Defaults
#' to TRUE
#' @param lagsIncluded If Dynamic = TRUE, how many lags should be included?
#' Defaults to 1.
#' @param faultsToTriggerAlarm the number of sequential faults needed to
#' trigger an alarm
#' @param ... Lazy dots for additional internal arguments
#'
#' @return a list of the following components: FaultChecks - an xts data matrix
#' containing the SPE monitoring statistic and logical flagging indicator, the
#' Hotelling's T2 monitoring statitisic and logical flagging indicator, and the
#' Alarm indicator; Non_Alarmed_Obs - an xts data matrix of all the non-Alarmed
#' observations; Alarms - and an xts data matrix of the features and specific
#' alarms for Alarmed observations, where the alarm code is as follows: 0 = no
#' alarm, 1 = Hotelling's T2 alarm, 2 = SPE alarm, and 3 = both alarms.
#'
#' @details This function is designed to identify and sort out sequences of
#' observations which fall outside normal operating conditions. This function
#' uses non-parametric density estimation to calculated the 1 - alpha quantiles
#' of the SPE and Hotelling's T2 statistics from a set of training observations,
#' then flags any observation in the testing data set with statistics beyond
#' these calculated critical values. Becuase of naturaly variablity inherent in
#' all real data, we do not sort out observations simply because they are have
#' been flagged. This function records an alarm only for observations having
#' three (as set by the default argument value of "faultsToTriggerAlarm") flags
#' in a row. These alarm-positive observations are removed from the data set.
#'
#' @export
#'
#' @importFrom lazyeval lazy_dots
#' @importFrom lazyeval lazy_eval
#' @importFrom zoo zoo
#' @importFrom stats lag
#'
#' @examples
mspTrain <- function(data,
                       labelVector,
                       trainObs,
                       updateFreq = ceiling(0.5 * trainObs),
                       Dynamic = TRUE,
                       lagsIncluded = 1,
                       faultsToTriggerAlarm = 3,
                       ...){

  ls <- lazy_dots(...)

  # Lag the data
  if(Dynamic == TRUE){
    data <- lag(zoo(data), 0:-lagsIncluded)
  }
  data <- xts(data[-(1:lagsIncluded),])

  classes <- unique(labelVector)
  classData <- cbind(labelVector[-(1:lagsIncluded),], data)
  data_ls <- lapply(1:length(classes), function(i){
    data_df <- classData[classData[,1] == classes[i],]
    data_df[, -1]
  })
  names(data_ls) <- classes

  monitorResults <- lapply(classes, function(i){
    do.call(processMonitor,
            args = c(list(data = data_ls[[i]],
                          trainObs = floor(trainObs / length(classes)),
                          updateFreq = floor(updateFreq / length(classes)),
                          faultsToTriggerAlarm = faultsToTriggerAlarm),
                     lazy_eval(ls)))
  })

  names(monitorResults) <- classes

  FaultChecks <- lapply(classes, function(i){
    monitorResults[[i]]$FaultChecks
  })
  FaultChecks <- do.call(rbind, FaultChecks)

  Non_Alarmed_Obs <- lapply(classes, function(i){
    monitorResults[[i]]$Non_Alarmed_Obs
  })
  Non_Alarmed_Obs <- do.call(rbind, Non_Alarmed_Obs)

  Alarms <- lapply(classes, function(i){
    monitorResults[[i]]$Alarms
  })
  # Some of the alarm xts matrices are empty, and neither merge.xts() nor
  # rbind.xts() will work to bind an empty xts to a non-empty xts. Therefore,
  # we remove any empty xts objects. If all xts objects are empty, then we
  # return one of the empty ones.
  condition <- sapply(Alarms, function(i){
    # condition returns a logical vector where FALSE corresponds to an empty
    # xts object
    !is.null(dim(i))
  })
  if(sum(condition) != 0){
    # If there is at least one non-empty xts object in Alarms, then find the
    # non-empty ones and row bind their observations together.
    Alarms <- Alarms[condition]
    Alarms <- do.call(rbind, Alarms)
  }else{
    # Otherwise (all the xts objects are empty), return the first one.
    Alarms <- Alarms[[1]]
  }


  list(FaultChecks = FaultChecks,
       Non_Alarmed_Obs = Non_Alarmed_Obs,
       Alarms = Alarms)
}