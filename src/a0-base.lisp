(progn
  (set-function
   'DEFUN
   (%macro-lambda (name args body)
                  (list 'set-function (list 'quote name)
                        (list '%lambda args body))))

  (set-function
   'DEFMACRO
   (%macro-lambda (name args body)
                  (list 'set-function (list 'quote name)
                        (list '%macro-lambda args body))))


  (defun not (x)
    (if x nil t))

  (defun equal (x y)
    (if (eq x y) t
        (%let ((xt . (type-of x))
               (yt . (type-of y)))
              (if (not (eq xt yt))
                  nil
                  (if (eq xt 'cons)
                      (equal-lists x y)
                      (error xt))))))

  (defun equal-lists (x y)
    (if (eq x nil)
        (eq y nil)
        (if (eq y nil)
            nil
            (if (equal (car x) (car y))
                (equal-lists (cdr x) (cdr y))
                nil))))

  (defmacro assert (x)
    (list 'if x nil (list 'error (list 'quote x))))

  (defun base-test ()
    (progn
      (assert (equal 1 1))
      (assert (equal '(1 2 3) '(1 2 3)))
      (assert (equal '((1 2) (3 4)) '((1 2) (3 4))))
      (assert (not (equal '(1) '(1 2))))
      )))
